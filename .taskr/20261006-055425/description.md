Ids are currently not being padding with 0 values for single digit month, days, hours, minutes, or seconds.

### Fix
This should be padding the numbers to ensure length of 2 so that id sizes are consistent