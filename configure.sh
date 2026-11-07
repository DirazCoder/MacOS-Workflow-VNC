#configure.sh VNC_USER_PASSWORD VNC_PASSWORD TS_AUTHKEY

#disable spotlight indexing
sudo mdutil -i off -a

#Create new account
sudo dscl . -create /Users/vncuser
sudo dscl . -create /Users/vncuser UserShell /bin/bash
sudo dscl . -create /Users/vncuser RealName "VNC User"
sudo dscl . -create /Users/vncuser UniqueID 1001
sudo dscl . -create /Users/vncuser PrimaryGroupID 80
sudo dscl . -create /Users/vncuser NFSHomeDirectory /Users/vncuser
sudo dscl . -passwd /Users/vncuser "$1"
sudo createhomedir -c -u vncuser > /dev/null

#Remote Management (kickstart/ARDAgent) always gave a black screen here, so use plain Screen Sharing instead; the two fight over port 5900.
#Same approach as https://gist.github.com/timsutton/31344ef60dbd4d64aca5b3287c0644e8 (macOS 14 version in the comments, tested on GitHub Actions)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -stop || echo "ARDAgent was not running"
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

#the runner image only grants screen capture to bash; SIP is off here, so TCC.db is writable
tcc_db="/Library/Application Support/com.apple.TCC/TCC.db"
epoch="$(date +%s)"
sudo sqlite3 "$tcc_db" "DELETE FROM access WHERE client = 'com.apple.screensharing.agent'; INSERT INTO access(service,client,client_type,auth_value,auth_reason,auth_version,indirect_object_identifier_type,flags,last_modified,last_reminded) VALUES('kTCCServicePostEvent','com.apple.screensharing.agent',0,2,4,1,0,0,$epoch,$epoch); INSERT INTO access(service,client,client_type,auth_value,auth_reason,auth_version,indirect_object_identifier_type,flags,last_modified,last_reminded) VALUES('kTCCServiceScreenCapture','com.apple.screensharing.agent',0,2,4,1,0,0,$epoch,$epoch);" || echo "tcc insert failed"
sudo killall tccd || true

#tailscale instead of a public relay: bore.pub wasn't reachable, and this keeps VNC private
brew install tailscale
sudo tailscaled --tun=userspace-networking > /tmp/tailscaled.log 2>&1 &
sleep 3
sudo tailscale up --authkey="$3" --hostname=gh-mac
