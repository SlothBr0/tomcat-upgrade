#!/bin/bash

# FILES directory should be created before beginning. Identify where this will be (typically /u01/app/IS-OPS)
# Requires Tomcat.service file to point to symlink specified
# Make sure the following are loaded into the directory, all necessary .jar files for /lib, all necessary .xml files for /conf
# Make sure to set desired version and User (i.e. tomcat)

# Tomcat version to install
TOMCAT_VERSION=9.0.110

# Update URL for new versions
SATELLITE_URL="https://satellite6-prod.pima.edu/pulp/content/Pima_Community_College/Library/custom/Tomcat/Tomcat-9/apache-tomcat-$TOMCAT_VERSION.tar.gz"

# Set Tomcat user (MODIFY TO TOMCAT BEFORE RUNNING ON BANNER SYSTEM)
TOMCAT=tomcat

# Set the installation/resources directories
INSTALL_DIR="/u01/app/tomcat-$TOMCAT_VERSION"
FILES="/u01/app/IS-OPS/"
APP_DIR="/u01/app"
SETENV_PATH="$INSTALL_DIR/bin/setenv.sh"
SERVICE_FILE="/etc/systemd/system/tomcat.service"

# Check if Tomcat Version is already current
if [ -d "$INSTALL_DIR" ]; then
	echo "Tomcat Version is Current. Exiting."
	exit 0
else

# Download and extract Tomcat
echo "Downloading Apache Tomcat $TOMCAT_VERSION..."
wget -q --no-check-certificate "$SATELLITE_URL" -O $APP_DIR/apache-tomcat-$TOMCAT_VERSION.tar.gz wait 

echo "Extracting Tomcat Archive..."
tar xf $APP_DIR/apache-tomcat-$TOMCAT_VERSION.tar.gz -C $APP_DIR 
mv $APP_DIR/apache-tomcat-$TOMCAT_VERSION $INSTALL_DIR

# Copy Files
echo "Copying Files..."
cp $FILES/*.jar $INSTALL_DIR/lib
cp -f $FILES/*.xml $INSTALL_DIR/conf
cp $APP_DIR/tomcat/webapps/*.war $INSTALL_DIR/webapps/

# Remove uneeded files
rm -rf $INSTALL_DIR/webapps/docs $INSTALL_DIR/webapps/examples $INSTALL_DIR/webapps/ROOT $INSTALL_DIR/webapps/host-manager $INSTALL_DIR/webapps/manager 

# Check for setenv
if [ ! -e "$APP_DIR/tomcat/bin/setenv.sh" ]; then
       echo "setenv does not exist."
else
       echo "setenv exists; modifying..."
       OLD_TOMCAT_VER=$(sed -n 's/^CATALINA_HOME=".*\/tomcat-\([0-9.]*\)".*$/\1/p' $APP_DIR/tomcat/bin/setenv.sh)
       cp $APP_DIR/tomcat/bin/setenv.sh $INSTALL_DIR/bin/
# Modify setenv.sh
       sed -i s/$OLD_TOMCAT_VER/$TOMCAT_VERSION/g $SETENV_PATH
fi

# Set permissions on directory
echo "Setting permissions..."
chgrp -R $TOMCAT "$INSTALL_DIR"
chmod -R g+r "$INSTALL_DIR/conf"
chmod g+x "$INSTALL_DIR/conf"
chown -R $TOMCAT "$INSTALL_DIR"/webapps/ "$INSTALL_DIR"/work/ "$INSTALL_DIR"/temp/ "$INSTALL_DIR"/logs/ "$INSTALL_DIR"/bin
chown $TOMCAT "$INSTALL_DIR"/conf/
find "$INSTALL_DIR/bin" -type f -name "*.sh" -exec chmod g+x {} \;
find "$INSTALL_DIR/lib" -type f -name "*" -exec chmod 644 {} \;

# Check for tomcat.service file
if [ ! -e "$SERVICE_FILE" ]; then
        echo "Service File does not exist at: $SERVICE_FILE. Creating Service File."

# Write Service File
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Tomcat Server (tomcat)
After=network.target

[Service]
Type=simple

WorkingDirectory=/u01/app/tomcat/bin
ExecStart=/u01/app/tomcat/bin/catalina.sh run

ExecStopPost=/bin/rm -rf /u01/app/tomcat/temp/*

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemctl daemon
systemctl daemon-reload

else
        echo "Service file exists at: $SERVICE_FILE."
fi

# Stop tomcat
systemctl stop tomcat

# Create symbolic link
cd $APP_DIR
unlink tomcat
ln -s "$INSTALL_DIR" tomcat

# Start Tomcat
systemctl start tomcat
echo "Tomcat has finished upgrading. Please start or check status of Tomcat using systemd"

rm -rf $APP_DIR/apache-tomcat-$TOMCAT_VERSION.tar.gz

fi
