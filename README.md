![Trigger: Push action](https://github.com/yurug/get-gitlab-forks/workflows/Trigger:%20Push%20action/badge.svg)

# Get Gitlab Forks

Do you want to retrieve all the forks of your gitlab project you have
access to? If so, this script could help you.

To learn how to use it:

```
./get-gitlab-forks.sh -h
```

## Dependencies

You will need:

- bash >= 5
- jq
- curl

## Typical usage

If you are assigning programming projects to students, I found the following process sufficiently simple and efficient:

1. Create a public gitlab project containing the base source files, specifications and tests.
2. Ask students to fork the gitlab project with a *private* visibility and to make you a member of their gitlab project.
3. Use this script to retrieve all the forks.

This process enjoys the following properties:
- It is easy for students to get updates from the base project.
- You do not have to collect students projects manually, everything is automated.
- The script alerts you if a student forgot to make its project private.
- You can post the list of forked projects to the course mailing list for students to know if they followed the instructions correctly.



