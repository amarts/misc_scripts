require 'json'
require 'date'

# ssh amarts@review.gluster.org gerrit query --current-patch-set --files --start 1 --format JSON status:open > dump.json
# ssh amarts@review.gluster.org gerrit query --current-patch-set --files --start 501 --format JSON status:open >> dump.json
# sed -i -e '/{"type":"stats"/d' dump.json
# sed -e 's/}$/},/g' dump.json > test.json
# possible to have an extra comma at the end, remove it, if exists
# $(echo "["; cat test.json; echo "]") > array.json
# cat array.json | python -mjson.tool > pretty.json


fd = File.open("pretty.json");

obj = JSON.load(fd); 

projects = {}

owner = {}

count = 0

# Get list of projects
obj.each do |patch|
  updated = Time.at(patch['lastUpdated']).to_datetime;
  
  next if updated >= (Date.today - 60)
    
  if not projects[patch["project"]]
    projects[patch["project"]] = []
  end
  projects[patch["project"]] << patch

  count = count + 1
end

puts "### Total patches older than 60days is #{count}"

#List down the patches per project:
projects.each do |proj,patches|
  owner = {}

  # Go through each patch, and mark it as per owner.
  patches.each do |p|
    updated = Time.at(p['lastUpdated']).to_datetime;

    next if updated >= (Date.today - 60)

    if not owner[p["owner"]["name"]]
      owner[p["owner"]["name"]] = []
    end
    owner[p["owner"]["name"]] << p
  end

  puts "" # new line after every project
  puts "## #{proj}"
  owner.each do |o, ptchs|
    puts "* [#{o}](#{ptchs[0]["owner"]["email"]}) (#{ptchs.length})"
    ptchs.each do |p|

      next if not p['branch'] == "master";

      files = p['currentPatchSet']['files'];
      skip = true
      files.each do |f|
        # Change this as per the need
        if f['file'].include?("xlators/mgmt/") or f['file'].include?("cli/")
          skip = false
          break
        end
      end
      next if skip
      
      created = Time.at(p['createdOn']);
      updated = Time.at(p['lastUpdated']);

      approvals = p['currentPatchSet']['approvals'];

      negative = false
      if approvals 
        approvals.each do |a|
          negative = true if ["-1", "-2"].include?(a['value'])
        end
      end
      puts "  - create:#{created.strftime("%Y-%m-%d")}, updated:#{updated.strftime("%Y-%m-%d")}, [#{p['subject']}](#{p['url']}), any-failure:#{negative.to_s}"
    end
    puts ""
  end
end
