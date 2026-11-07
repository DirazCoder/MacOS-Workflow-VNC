#configure.sh VNC_USER_PASSWORD VNC_PASSWORD NGROK_AUTH_TOKEN

#disable spotlight indexing
sudo mdutil -i off -a

#Create new account
sudo dscl . -create /Users/vncuser
sudo dscl . -create /Users/vncuser UserShell /bin/bash
sudo dscl . -create /Users/vncuser RealName "VNC User"
sudo dscl . -create /Users/vncuser UniqueID 1001
sudo dscl . -create /Users/vncuser PrimaryGroupID 80
sudo dscl . -create /Users/vncuser NFSHomeDirectory /Users/vncuser
sudo dscl . -passwd /Users/vncuser $1
sudo dscl . -passwd /Users/vncuser $1
sudo createhomedir -c -u vncuser > /dev/null

#Enable VNC
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 

#VNC password - http://hints.macworld.com/article.php?story=20071103011608872
echo $2 | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

#the runner image grants screen capture to bash but not to ARDAgent, which gives a black screen; SIP is off here so TCC.db is writable
tcc_db="/Library/Application Support/com.apple.TCC/TCC.db"
ard_app=/System/Library/CoreServices/RemoteManagement/ARDAgent.app
ard_id=$(defaults read "$ard_app/Contents/Info" CFBundleIdentifier)
for service in kTCCServiceScreenCapture kTCCServiceAccessibility kTCCServicePostEvent; do
  sudo sqlite3 "$tcc_db" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, flags) VALUES ('$service', '$ard_id', 0, 2, 4, 1, 0), ('$service', '$ard_app/Contents/MacOS/ARDAgent', 1, 2, 4, 1, 0);" || echo "tcc insert failed for $service"
done
sudo killall tccd || true

#Start VNC/reset changes
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

#tailscale instead of a public relay: bore.pub wasn't reachable, and this keeps VNC private
brew install tailscale
sudo tailscaled --tun=userspace-networking > /tmp/tailscaled.log 2>&1 &
sleep 3
sudo tailscale up --authkey="$3" --hostname=gh-mac
