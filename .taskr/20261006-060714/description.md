Tasks should be able to have any properties updating.

Updating should behave like a patch. command should just specify what needs to change. Old versions of a task should be put into a `versions` folder.
The versions folder should have tasks with an incrementing version (`v1.task`, `v2.task`, `v3.task`, etc.)

The `author` of the task should never change, instead each version should a list field of `changed` that has a list of properties changed.
It should also have a `deprecated_at` field that represents what UTC time it was deprecated, and `deprecated_by` for who made the change