#!/bin/bash

# Script to install gitorious on Ubuntu 10.04 machines
# Followed instruction from : 
# http://www.silly-science.co.uk/2010/12/12/installing-gitorious-on-ubuntu-10-04-howto/

function install_dependency()
{
    apt-get update

    apt-get --yes install build-essential zlib1g-dev tcl-dev libexpat-dev libcurl4-openssl-dev postfix apache2 mysql-server mysql-client apg geoip-bin libgeoip1 libgeoip-dev sqlite3 libsqlite3-dev imagemagick libpcre3 libpcre3-dev zlib1g zlib1g-dev libyaml-dev libmysqlclient15-dev apache2-dev libonig-dev phpmyadmin libmagick++-dev zip unzip memcached git-core git-svn git-doc git-cvs irb sphinxsearch

    apt-get --yes install uuid uuid-dev openjdk-6-jre apache2

    return 0;
}

function install_activemq ()
{
    # check if activemq user exists, if not proceed
    if [ grep -q "activemq" /etc/passwd ] ; then
        return 0;
    fi

    #wget http://www.powertech.no/apache/dist/activemq/apache-activemq/5.2.0/apache-activemq-5.2.0-bin.tar.gz
    wget http://apache.techartifact.com/mirror/activemq/apache-activemq/5.6.0/apache-activemq-5.6.0-bin.tar.gz
    tar xzvf apache-activemq-5.6.0-bin.tar.gz -C /usr/local/
    echo "export ACTIVEMQ_HOME=/usr/local/apache-activemq-5.6.0" >> /etc/activemq.conf
    echo "export JAVA_HOME=/usr/" >> /etc/activemq.conf
    adduser --system --no-create-home activemq
    chown -R activemq /usr/local/apache-activemq-5.6.0/data
    # Now to turn off the default multicasting activemq does, or other
    # brokers on the same network will receive your queue items. Edit
    # the networkConnectors setting in /usr/local/apache-activemq-5.2.0/conf/activemq.xml
    # to something like this:
    cat > /usr/local/apache-activemq-5.6.0/conf/activemq.xml <<EOF
<networkConnectors>
<!-- by default just auto discover the other brokers -->
<!-- Example of a static configuration: -->
<networkConnector name="localhost" uri="static://(tcp://127.0.0.1:61616)"/>
</networkConnectors>

EOF

    #Now setup the startup script for ActiveMQ
    #cd /tmp
    wget http://launchpadlibrarian.net/15645459/activemq
    mv activemq /etc/init.d/activemq
    chmod +x /etc/init.d/activemq
    update-rc.d activemq defaults
    service activemq start

    return 0;
}

function install_ruby()
{
    if [ -d /usr/bin/gems ] ; then
        gem update --system;
        return 0;
    fi

    wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2012.02_amd64_ubuntu10.04.deb
    dpkg -i ruby-enterprise*

    wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.24.tgz

    tar -xf rubygems-1.8.24.tgz
    (cd rubygems-1.8.24; ruby setup.rb);
    ln -s /usr/bin/gems1.8 /usr/bin/gems;

# Install required gems
    gem install -b --no-ri --no-rdoc rmagick chronic geoip daemons hoe echoe ruby-yadis ruby-openid mime-types diff-lcs json rack ruby-hmac rake stompserver passenger rails ultrasphinx mysql
    gem install -b --no-ri --no-rdoc -v 1.0.1 rack
    gem install -b --no-ri --no-rdoc -v 1.3.1.1 rdiscount
    gem install -b --no-ri --no-rdoc -v 1.1 stomp
#Setup links to the correct versions:
    ln -s /var/lib/gems/1.8/gems/rake-0.8.7/bin/rake /usr/bin/rake
    ln -s /var/lib/gems/1.8/gems/stompserver-0.9.9/bin/stompserver /usr/bin/stompserver

    return 0;
}

function install_gitorious()
{
# Download the gitorious package:
    if [ -d /var/www/gitorious ] ; then
        return 0;
    fi

    git clone git://gitorious.org/gitorious/mainline.git /var/www/gitorious
#Copy the required init.d files:
    cp /var/www/gitorious/doc/templates/ubuntu/git-daemon /etc/init.d/
    cp /var/www/gitorious/doc/templates/ubuntu/git-ultrasphinx /etc/init.d/
#Change /etc/init.d/git-daemon to have the following line:
    GIT_DAEMON="/usr/bin/ruby /var/www/gitorious/script/git-daemon -d"
#Create the git-poller and stomp initialisation scripts from the gitorious tutorial
#Set the correct permissions and activate the initialisation files:
    chmod 755 /etc/init.d/git-ultrasphinx /etc/init.d/git-daemon /etc/init.d/stomp /etc/init.d/git-poller
    update-rc.d stomp defaults
    update-rc.d git-daemon defaults
    update-rc.d git-ultrasphinx defaults
    update-rc.d git-poller defaults
    
    return 0;
}

setup_apache2()
{
 #Run apache setup script and follow the instructions:
    /usr/local/bin/passenger-install-apache2-module
#Create /etc/apache2/mods-available/passenger.load with the following contents:
    cat > /etc/apache2/mods-available/passenger.load <<EOF
LoadModule passenger_module /usr/local/lib/ruby/gems/1.8/gems/passenger-3.0.15/ext/apache2/mod_passenger.so
PassengerRoot /usr/local/lib/ruby/gems/1.8/gems/passenger-3.0.15
PassengerRuby /usr/local/bin/ruby

EOF
#Enable apache2 modules and default ssl site:
    a2enmod passenger
    a2enmod rewrite
    a2enmod ssl
    a2ensite default-ssl
#Restart apache:
    service apache2 restart

#Add a 'git' user to MySQL with global create privileges. Also give it all privileges on gitorious_production. 
#Create /etc/apache2/sites-available/gitorious and /etc/apache2/sites-available/gitorious-ssl
cat > /etc/apache2/sites-available/gitorious  <<EOF
<VirtualHost *:80>
ServerName your.server.com    
DocumentRoot /var/www/gitorious/public    
</VirtualHost>

EOF

cat > /etc/apache2/sites-available/gitorious-ssl <<EOF
<IfModule mod_ssl.c>
<VirtualHost _default_:443>  
DocumentRoot /var/www/gitorious/public    
SSLEngine on    
SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem    
SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key    
BrowserMatch ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0    
</VirtualHost>  
</IfModule>

EOF

# Enable and disable the appropriate sites as follows:
    a2dissite default
    a2dissite default-ssl
    a2ensite gitorious
    a2ensite gitorious-ssl

    return 0;
}

function global_setup()
{
#Add a user 'git' to the system:
    adduser --system --home /var/www/gitorious/ --no-create-home --group --shell /bin/bash git

#Set permissions on the gitorious tree:
    chown -R git:git /var/www/gitorious
#Now run the following sequence of commands:
    su - git -c "cd /var/www/gitorious; mkdir .ssh; touch .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys; mkdir tmp/pids; mkdir repositories; mkdir tarballs; cp config/database.sample.yml config/database.yml; cp config/gitorious.sample.yml config/gitorious.yml; cp config/broker.yml.example config/broker.yml;"

#Edit config/database.yml: Remove every section but production
#Edit config/gitorious.yml: Remove every section but production (so at the top tab level only production: should exist)
#Set the gitorious.yml lines configurations like so (other entries not listed are to be left as defaults):

# cookie_secret: [set to output of apg -m 64]
# repository_base_path: "/var/www/gitorious/repositories"
# gitorious_client_port: 80
# gitorious_client_host: your.gitorious.domain.here
# gitorious_host: your.gitorious.domain.here
# archive_cache_dir: "/var/www/gitorious/tarballs"
# archive_work_dir: "/tmp/tarballs-work"
# hide_http_clone_urls: true
# is_gitorious_dot_org: false
#Run the following (note if you have to drop out to root again because it tells you that you missed some gems then remember to do the export again when you have su'd back into the git user!):

# $ export RAILS_ENV=production
# $ rake db:create
# $ rake db:migrate
# $ rake ultrasphinx:bootstrap

# Add the following line to the crontab:
#* * * * * cd /var/www/gitorious && /usr/bin/rake ultrasphinx:index RAILS_ENV=production
#Now create an admin user:
#$ env RAILS_ENV=production ruby script/create_admin
#Exit being the 'git' user and restart apache as root

    service apache2 restart
#Now start the git-daemon service:
    service git-daemon start

#Now you may find the login page not working, to fix this do the following (thanks to [2]):
#    gem uninstall i18n
#    gem install i18n -v=0.1
    service apache2 restart
#Now create the adminstrator user:
#$ env RAILS_ENV=production ruby script/create_admin

    return 0;
}

function fail()
{
    echo "failed to install gitorious package @ $1"
    exit 1;
}

function main()
{
    tempdir=$(mktemp -d);
    cd $tempdir;
    install_dependency || fail "dependency";

    install_activemq || fail "activemq";

    install_ruby || fail "ruby";

    install_gitorious || fail "gitorious";

    setup_apache2 || fail "apache2";

    global_setup || fail "global setup";

    cd -;

    #rm $tempdir;

    return 0;
}

main "$@";