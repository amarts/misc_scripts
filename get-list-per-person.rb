require 'json'


# ssh amarts@review.gluster.org gerrit query --current-patch-set --files --start 1 --format JSON status:open > dump.json
# ssh amarts@review.gluster.org gerrit query --current-patch-set --files --start 501 --format JSON status:open >> dump.json
# sed -i -e '/{"type":"stats"/d' dump.json
# sed -e 's/}$/},/g' dump.json > test.json
# possible to have an extra comma at the end, remove it, if exists
# $(echo "["; cat test.json; echo "]") > array.json
# cat array.json | python -mjson.tool > pretty.json

# After pretty.json is ready, execute 'ruby get-list-per-person.rb'

fd = File.open("pretty.json");

obj = JSON.load(fd); 

projects = {}

owner = {}

# Get list of projects
obj.each do |patch|
  if not projects[patch["project"]]
    projects[patch["project"]] = []
  end
  projects[patch["project"]] << patch
end


#List down the patches per project:
projects.each do |proj,patches|
  owner = {}

  # Go through each patch, and mark it as per owner.
  patches.each do |p|
    if not owner[p["owner"]["name"]]
      owner[p["owner"]["name"]] = []
    end
    owner[p["owner"]["name"]] << p
  end

  puts "" # new line after every project
  puts "## #{proj}"
  owner.each do |o, ptchs|
    puts "* [#{o}](#{ptchs[0]["owner"]["email"]})"
    ptchs.each do |p|
      created = Time.at(p['createdOn']);
      updated = Time.at(p['lastUpdated']);
      puts ""
      puts " - #{created.strftime("%Y-%m-%d")}: (#{p["branch"]}) [#{p['subject']}](#{p['url']}), last updated #{updated.strftime("%Y-%m-%d")}"
    end
    puts ""
  end
end
