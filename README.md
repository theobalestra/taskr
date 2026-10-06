```bash
taskr list
```

```bash
taskr complete {id}
```

```bash
taskr add --tags backend,bug,techdebt --priority 10
```


NOTE: Custom fields not yet supported
Example structure:

`{taskId}/task.md`
```
taskr_version: 1

name: string
status: string
priority: int
tags:
- tag1
- tag2
- tag3
custom_{field_name}: value

```

`{taskId}/description.md`
```markdown
## This is the description
```