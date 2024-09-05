# Contributing to PARKIT

This project is an Open Development project and welcomes contributions from everyone who finds it useful or lacking.

## Code Of Conduct

This project adheres to the Adobe [code of conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to cstaub at adobe dot com.

## Things to Keep in Mind

This project uses a **commit then review** process, which means that for approved maintainers, changes can be merged immediately, but will be reviewed by others.

For other contributors, a maintainer of the project has to approve the pull request.

# Before You Contribute

* Check that there is an existing issue in GitHub issues
* Check if there are other pull requests that might overlap or conflict with your intended contribution

# How to Contribute

1. Fork the repository
2. Make some changes on a branch on your fork
3. Create a pull request from your branch

In your pull request, outline:

* What the changes intend
* How they change the existing code
* If (and what) they breaks
* Start the pull request with the GitHub issue ID, e.g. #123

Each commit message that is not part of a pull request:

* Should contain the issue ID like `#123`
* Can contain the tag `[trivial]` for trivial changes that don't relate to an issue

## Commit Message Format

This project uses a structured commit changelog format that should be used for every commit. Use `npm run commit` instead of your usual `git commit` to generate commit messages using a wizard.

```bash
# either add all changed files
$ git add -A
# or selectively add files
$ git add file.rb
# then commit
$ git commit
```

# How Contributions get Reviewed

One of the maintainers will look at the pull request within one week. Feedback on the pull request will be given in writing, in GitHub.
