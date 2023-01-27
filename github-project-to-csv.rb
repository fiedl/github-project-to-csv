require 'json'
require 'csv'
require 'pry'

class GithubQuery
  attr_accessor :query, :result

  def self.execute(query)
    github_query = self.new
    github_query.query = query
    github_query.execute
    github_query
  end

  def execute
    @result = JSON.parse(`gh api graphql -f query='#{query}'`)
  end
end

class GithubProject < GithubQuery
  def self.find_by(org:, number:)
    execute("
      query{
        organization(login: \"#{org}\"){
          projectV2(number: #{number}) {
            id
          }
        }
      }
    ")
  end

  def id
    result.dig("data", "organization", "projectV2", "id")
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
