#!/usr/bin/python
# Lovely / horrible hack to take a bunch of data parsed from years of logs and
# merge it with the fake create map built by our already hacky utility.  This
# gives us a much better starting list of create dates for eperson records.
# When an id wasn't found in the logs, it's assumed they were created no later
# than the next sequential id.

from datetime import datetime, date

# Get all the dates which were parsed from logs into a lookup
create_logs_map = {}
with open("eperson-create-from-logs.tsv") as f:
  for line in f:
    dt_string, eperson_id = line.split("\t")
    create_date = datetime.strptime(dt_string, "%Y-%m-%d")
    create_logs_map[int(eperson_id)] = create_date

# Read and then reverse the "guess" create map.  The reverse allows us to know
# when the next user's create date was while traversing the data.
guessmap_lines = []
with open("eperson-createmap.tsv") as f:
  for line in f:
    guessmap_lines.append(line.strip())
guessmap_lines.reverse()

last_date = None
for line in guessmap_lines:
  eperson_id, dt_string = line.split("\t")
  eperson_id = int(eperson_id)
  create_date = datetime.strptime(dt_string, "%m/%d/%y")

  if eperson_id in create_logs_map:
    create_date = create_logs_map[eperson_id]
  elif last_date != None and last_date < create_date:
    create_date = last_date

  last_date = create_date
  print "%d\t%s" % (eperson_id, create_date.strftime("%m/%d/%y"))
