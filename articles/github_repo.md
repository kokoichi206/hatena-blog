# Github のリポジトリ一覧取得

Github は GraphQL のAPIも提供していますが、今回は[ Github RestAPI ](https://docs.github.com/en/rest)を使用して、public リポジトリ一覧を取得してみようと思います。

public なリポジトリを持ってくるだけなら

`https://api.github.com/users/<username>/repos`

にアクセスすることで可能です。他人のリポジトリに対しても行うことができます。

結果は以下のような json で返ってきます。

```sh
[
  {
    "id": 379894047,
    "node_id": "MDEwOlJlcG9zaXRvcnkzNzk4OTQwNDc=",
    "name": "search-save",
    "full_name": "kokoichi206/search-save",
    "private": false,
    "owner": {
      "login": "kokoichi206",
      "id": 52474650,
      "node_id": "MDQ6VXNlcjUyNDc0NjUw",
      "avatar_url": "https://avatars.githubusercontent.com/u/52474650?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/kokoichi206",
      "html_url": "https://github.com/kokoichi206",
      "followers_url": "https://api.github.com/users/kokoichi206/followers",
      "following_url": "https://api.github.com/users/kokoichi206/following{/other_user}",
      "gists_url": "https://api.github.com/users/kokoichi206/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/kokoichi206/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/kokoichi206/subscriptions",
      "organizations_url": "https://api.github.com/users/kokoichi206/orgs",
      "repos_url": "https://api.github.com/users/kokoichi206/repos",
      "events_url": "https://api.github.com/users/kokoichi206/events{/privacy}",
      "received_events_url": "https://api.github.com/users/kokoichi206/received_events",
      "type": "User",
      "site_admin": false
    },
    "html_url": "https://github.com/kokoichi206/search-save",
    "description": null,
    "fork": false,
    "url": "https://api.github.com/repos/kokoichi206/search-save",
    "forks_url": "https://api.github.com/repos/kokoichi206/search-save/forks",
    "keys_url": "https://api.github.com/repos/kokoichi206/search-save/keys{/key_id}",
    "collaborators_url": "https://api.github.com/repos/kokoichi206/search-save/collaborators{/collaborator}",
    "teams_url": "https://api.github.com/repos/kokoichi206/search-save/teams",
    "hooks_url": "https://api.github.com/repos/kokoichi206/search-save/hooks",
    "issue_events_url": "https://api.github.com/repos/kokoichi206/search-save/issues/events{/number}",
    "events_url": "https://api.github.com/repos/kokoichi206/search-save/events",
    "assignees_url": "https://api.github.com/repos/kokoichi206/search-save/assignees{/user}",
    "branches_url": "https://api.github.com/repos/kokoichi206/search-save/branches{/branch}",
    "tags_url": "https://api.github.com/repos/kokoichi206/search-save/tags",
    "blobs_url": "https://api.github.com/repos/kokoichi206/search-save/git/blobs{/sha}",
    "git_tags_url": "https://api.github.com/repos/kokoichi206/search-save/git/tags{/sha}",
    "git_refs_url": "https://api.github.com/repos/kokoichi206/search-save/git/refs{/sha}",
    "trees_url": "https://api.github.com/repos/kokoichi206/search-save/git/trees{/sha}",
    "statuses_url": "https://api.github.com/repos/kokoichi206/search-save/statuses/{sha}",
    "languages_url": "https://api.github.com/repos/kokoichi206/search-save/languages",
    "stargazers_url": "https://api.github.com/repos/kokoichi206/search-save/stargazers",
    "contributors_url": "https://api.github.com/repos/kokoichi206/search-save/contributors",
    "subscribers_url": "https://api.github.com/repos/kokoichi206/search-save/subscribers",
    "subscription_url": "https://api.github.com/repos/kokoichi206/search-save/subscription",
    "commits_url": "https://api.github.com/repos/kokoichi206/search-save/commits{/sha}",
    "git_commits_url": "https://api.github.com/repos/kokoichi206/search-save/git/commits{/sha}",
    "comments_url": "https://api.github.com/repos/kokoichi206/search-save/comments{/number}",
    "issue_comment_url": "https://api.github.com/repos/kokoichi206/search-save/issues/comments{/number}",
    "contents_url": "https://api.github.com/repos/kokoichi206/search-save/contents/{+path}",
    "compare_url": "https://api.github.com/repos/kokoichi206/search-save/compare/{base}...{head}",
    "merges_url": "https://api.github.com/repos/kokoichi206/search-save/merges",
    "archive_url": "https://api.github.com/repos/kokoichi206/search-save/{archive_format}{/ref}",
    "downloads_url": "https://api.github.com/repos/kokoichi206/search-save/downloads",
    "issues_url": "https://api.github.com/repos/kokoichi206/search-save/issues{/number}",
    "pulls_url": "https://api.github.com/repos/kokoichi206/search-save/pulls{/number}",
    "milestones_url": "https://api.github.com/repos/kokoichi206/search-save/milestones{/number}",
    "notifications_url": "https://api.github.com/repos/kokoichi206/search-save/notifications{?since,all,participating}",
    "labels_url": "https://api.github.com/repos/kokoichi206/search-save/labels{/name}",
    "releases_url": "https://api.github.com/repos/kokoichi206/search-save/releases{/id}",
    "deployments_url": "https://api.github.com/repos/kokoichi206/search-save/deployments",
    "created_at": "2021-06-24T10:58:10Z",
    "updated_at": "2021-06-24T23:59:39Z",
    "pushed_at": "2021-06-24T23:59:37Z",
    "git_url": "git://github.com/kokoichi206/search-save.git",
    "ssh_url": "git@github.com:kokoichi206/search-save.git",
    "clone_url": "https://github.com/kokoichi206/search-save.git",
    "svn_url": "https://github.com/kokoichi206/search-save",
    "homepage": null,
    "size": 3871,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": "JavaScript",
    "has_issues": true,
    "has_projects": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": false,
    "forks_count": 0,
    "mirror_url": null,
    "archived": false,
    "disabled": false,
    "open_issues_count": 0,
    "license": null,
    "forks": 0,
    "open_issues": 0,
    "watchers": 0,
    "default_branch": "main"
  }
  ...
]
```

以下は取得した json のうち、"clone_url" のみを表示さるようなものです。

```sh
$ curl https://api.github.com/users/kokoichi206/repos | grep "clone_url" | awk '{print $2}' | tr -d '",'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  165k  100  165k    0     0  1102k      0 --:--:-- --:--:-- --:--:-- 1102k
https://github.com/kokoichi206/ai_web_app_flask.git
https://github.com/kokoichi206/android-app.git
...
```

