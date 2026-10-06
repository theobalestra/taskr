Allow querying for tasks with custom tags. This should be a fully complete query language that allows to do things like:

:priority gte 10 and (:tags includes feature or :tags includes v1) or :name like "query%"