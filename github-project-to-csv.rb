#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'pry'
require 'optparse'

class GithubQuery
  attr_accessor :query, :result

  def self.execute(query)
    github_query = self.new
    github_query.query = query
    github_query.execute
    github_query
  end

  def execute
    @result = `gh api graphql -f query='#{query}' 2>&1`
    raise "gh command line client not installed. https://cli.github.com/. install with 'brew install gh'" if @result.include? "gh: command not found"

    @result = JSON.parse(@result)
  end
end

class GithubProject < GithubQuery
  def self.find_by(org: nil, user: nil, number:)
    if org
      execute("
        query{
          organization(login: \"#{org}\"){
            projectV2(number: #{number}) {
              id
            }
          }
        }
      ")
    elsif user
      execute("
        query{
          user(login: \"#{user}\"){
            projectV2(number: #{number}) {
              id
            }
          }
        }
      ")
    else
      raise "Neither user nor org given"
    end
  end

  def id
    result.dig("data", "organization", "projectV2", "id") || result.dig("data", "user", "projectV2", "id")
  end

  def items
    GithubProjectItemCollection.find_by(project_id: id).items
  end

  def to_csv
    headers = items.collect(&:attributes).collect(&:keys).flatten.uniq
    rows = items.collect do |github_project_item|
      headers.collect { |h| github_project_item.attributes[h] }
    end
    CSV.generate(col_sep: ";") do |csv|
      csv << headers
      rows.each do |row|
        csv << row
      end
    end
  end
end

class GithubProjectItemCollection < GithubQuery
  def self.find_by(project_id:)
    execute("
      query{
        node(id: \"#{project_id}\") {
          ... on ProjectV2 {
            items(first: 100) {
              nodes {
                id
                content{
                  ... on DraftIssue {
                    title
                  }
                  ...on Issue {
                    title
                    number
                  }
                  ...on PullRequest {
                    title
                    number
                  }
                }
                fieldValues(first: 20) {
                  nodes {
                    ... on ProjectV2ItemFieldTextValue {
                      text
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                    ... on ProjectV2ItemFieldNumberValue {
                      number
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                    ... on ProjectV2ItemFieldDateValue {
                      date
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                    ... on ProjectV2ItemFieldIterationValue {
                      title
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      name
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                    ... on ProjectV2ItemFieldMilestoneValue {
                      milestone {
                        title
                      }
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                    ... on ProjectV2ItemFieldUserValue {
                      users(first: 10) {
                        nodes {
                          login
                        }
                      }
                      field {
                        ... on ProjectV2FieldCommon {
                          name
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    ")
  end

  def items
    result.dig("data", "node", "items", "nodes").collect do |node_data|
      github_project_item = GithubProjectItem.new
      github_project_item.result = node_data
      github_project_item
    end
  end
end

class GithubProjectItem < GithubQuery
  def id
    result.dig("id")
  end

  def number
    "##{result.dig("content", "number")}" if result.dig("content", "number")
  end

  def title
    [number, field_value_attributes["Title"]].join(" ")
  end

  def attributes
    direct_attributes.merge(field_value_attributes)
  end

  def direct_attributes
    {
      id: id,
      number: number,
      title: title
    }
  end

  def field_value_attributes
    result.dig("fieldValues", "nodes").to_h do |field_value_data|
      key = field_value_data.dig("field", "name")
      value = \
        field_value_data.dig("text") || \
        field_value_data.dig("number") || \
        field_value_data.dig("title") || \
        field_value_data.dig("name") || \
        field_value_data.dig("milestone", "title") || \
        field_value_data.dig("users", "nodes", 0, "login")
      [key, value]
    end.select { |key, value| not key.nil? }
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ./github-project-to-csv.rb [options]"

  opts.on("--project=URL", "Url of the github project, e.g. https://github.com/users/fiedl/projects/2") do |url|
    options[:project_url] = url
    options[:org], options[:project_number] = url.scan(/https:\/\/github.com\/orgs\/([^\/]*)\/projects\/([^\/]*)/).flatten if url.include? "orgs/"
    options[:user], options[:project_number] = url.scan(/https:\/\/github.com\/users\/([^\/]*)\/projects\/([^\/]*)/).flatten if url.include? "users/"
  end

  opts.on("--output=FILENAME", "Name of the csv file to export the project to, e.g. project.csv") do |filename|
    options[:filename] = filename
  end
end.parse!

raise "Missing project url" unless options[:project_url]
raise "Could not extract org or user from project url" unless options[:org] or options[:user]
raise "Could not extract project number from project url" unless options[:project_number].to_i > 0

github_project = GithubProject.find_by(org: options[:org], user: options[:user], number: options[:project_number])

csv_content = github_project.to_csv

if options[:filename]
  File.write options[:filename], csv_content
else
  print csv_content + "\n"
end
