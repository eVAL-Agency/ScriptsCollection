# Scripts Collection

A collection of system administration scripts for Linux and Windows administrators.

## Scripts

List of scripts available within this collection.

%%SCRIPTS_TABLE%%



## Scriptlets

Scriptlets are small pieces of reusable code that can be included in scripts during compilation.
This system provides a number of snippets, and more can be added by adding a `compile.sources` file in the root of the project
with the format:

```
scriptlet_type=github:repo_owner/repo_name
```

Where `scriptlet_type` is the directory that contains the scriptlets to include.

By default `main` is used to download sources, but a different branch can be specified by appending `:branch_name`.

%%SCRIPTLETS%%
