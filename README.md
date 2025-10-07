# Document-PSModule (by PSModule)

A GitHub Action that automates the generation of documentation for PowerShell modules using Markdown help files.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the
[Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Details

This action:
- Installs necessary modules, including `platyPS` for documentation generation.
- Loads helper scripts required by the documentation process.
- Generates Markdown documentation from PowerShell module files.
- Ensures Markdown documentation is properly formatted, with correctly tagged PowerShell code blocks.
- Adjusts Markdown file paths to mirror the structure of the source PowerShell module files.
- Outputs organized Markdown documentation suitable for publishing or distribution.

## Usage

Include this action in your workflow to automatically build and structure documentation for your PowerShell module.

### Inputs

| Input              | Description                                   | Required | Default     |
|--------------------|-----------------------------------------------|----------|-------------|
| `Name`             | Name of the module to document.               | No       | <Repo name> |
| `WorkingDirectory` | Directory from which the script will execute. | No       | `.`         |
| `ShowSummaryOnSuccess` | Show GitHub Step Summary even when all commands succeed. | No | `false` |

### Secrets

This action does not require any secrets.

### Outputs

This action does not have defined outputs.

### Example

```yaml
- name: Document PowerShell Module
  uses: PSModule/Document-PSModule@v1
  with:
    Name: 'MyModule'
    WorkingDirectory: './module-directory'
    ShowSummaryOnSuccess: true  # Optional: Show summary even on success
```
