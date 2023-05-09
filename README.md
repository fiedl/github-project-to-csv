# github-project-to-csv

Simple cli to export github v2 projects to csv

![Screenshot](https://user-images.githubusercontent.com/1679688/215134233-80bbbaab-c026-4937-b0d8-a42b11ab4e4b.png)

## Usage

```shell
./github-project-to-csv.rb --project https://github.com/users/fiedl/projects/2 --output project.csv
```

If you do encounter errors here, please check the [troubleshooting section](#troubleshooting) to make sure you have the correct ruby version and gems installed, or [run the script via docker](#running-with-docker).

## Installation

1. Install the [github cli](https://cli.github.com): `brew install gh`
2. Clone this repo: `git clone https://github.com/fiedl/github-project-to-csv.git`

## Using github personal access tokens

Instead of using the `gh` command-line client, this tool also supports [github personal access tokens](https://github.com/settings/tokens). However, github does only support classic personal access tokens for now; fine-grained tokens do not work, yet.

Create a classic token `xxx` at https://github.com/settings/tokens. Then:

```shell
./github-project-to-csv.rb --project https://github.com/users/fiedl/projects/2 --output project.csv --token xxx
```

## Running with docker

If you don't have a local ruby environment, it might be easiest to run this script via docker.

Install docker including the compose plugin: https://docs.docker.com/compose/install/

Then run this from the repository directory:

```shell
docker compose run app bundle exec ruby github-project-to-csv.rb --project https://github.com/users/fiedl/projects/2 --output project.csv --token xxx
```

When not using an access token, this might ask you to manually open a web browser and copy an authentication code in order to authenticate with github.

## Troubleshooting

### This script requires ruby version 3.2 or higher

Your local ruby version is too old. Please update according to the [ruby documentation](https://www.ruby-lang.org/en/documentation/installation/) or [run the script via docker](#running-with-docker).

### require: cannot load such file

Some gems are missing locally. Run:

    gem install pry httparty

Or [run the script via docker](#running-with-docker).

## Further Resources

- [Github documentation on the projects api](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects)
- [Introduction to GraphQL](https://docs.github.com/en/graphql/guides/introduction-to-graphql)
- [Understanding GraphQL Queries](https://graphql.org/learn/queries/)
- [Github GraphQL Object Reference](https://docs.github.com/en/graphql/reference/objects)
- [Github GraphQL API Explorer](https://docs.github.com/en/graphql/overview/explorer)

## Author and License

(c) 2023, Sebastian Fiedlschuster

MIT License
