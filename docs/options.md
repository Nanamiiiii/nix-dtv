# Options Reference

## Index

- [`hardware.px4_drv.enable`](#hardwarepx4_drvenable)
- [`hardware.px4_drv.package`](#hardwarepx4_drvpackage)
- [`services.dtv.enable`](#servicesdtvenable)
- [`services.dtv.edcb.enable`](#servicesdtvedcbenable)
- [`services.dtv.konomitv.enable`](#servicesdtvkonomitvenable)
- [`services.dtv.mirakurun.enable`](#servicesdtvmirakurunenable)
- [`services.dtv.openFirewall`](#servicesdtvopenfirewall)
- [`services.dtv.px4_drv.enable`](#servicesdtvpx4_drvenable)
- [`services.dtv.recordingDir`](#servicesdtvrecordingdir)
- [`services.dtv.recordingGroup`](#servicesdtvrecordinggroup)
- [`services.edcb.enable`](#servicesedcbenable)
- [`services.edcb.package`](#servicesedcbpackage)
- [`services.edcb.allowSmartCardAccess`](#servicesedcballowsmartcardaccess)
- [`services.edcb.bondriver`](#servicesedcbbondriver)
- [`services.edcb.bondriver.*.driverPath`](#servicesedcbbondriverdriverpath)
- [`services.edcb.bondriver.*.name`](#servicesedcbbondrivername)
- [`services.edcb.bondriver.*.settings`](#servicesedcbbondriversettings)
- [`services.edcb.bondriver.*.settingsFile`](#servicesedcbbondriversettingsfile)
- [`services.edcb.bondriver.*.tunerSettings`](#servicesedcbbondrivertunersettings)
- [`services.edcb.commonSettings`](#servicesedcbcommonsettings)
- [`services.edcb.commonSettingsFile`](#servicesedcbcommonsettingsfile)
- [`services.edcb.commonSettingsImmutable`](#servicesedcbcommonsettingsimmutable)
- [`services.edcb.epgDataCapBonSettings`](#servicesedcbepgdatacapbonsettings)
- [`services.edcb.epgDataCapBonSettingsFile`](#servicesedcbepgdatacapbonsettingsfile)
- [`services.edcb.epgDataCapBonSettingsImmutable`](#servicesedcbepgdatacapbonsettingsimmutable)
- [`services.edcb.httpPorts`](#servicesedcbhttpports)
- [`services.edcb.httpsPorts`](#servicesedcbhttpsports)
- [`services.edcb.manageRecordingDirs`](#servicesedcbmanagerecordingdirs)
- [`services.edcb.materialWebUI.enable`](#servicesedcbmaterialwebuienable)
- [`services.edcb.materialWebUI.package`](#servicesedcbmaterialwebuipackage)
- [`services.edcb.materialWebUI.extraCertificateSubjectAltNames`](#servicesedcbmaterialwebuiextracertificatesubjectaltnames)
- [`services.edcb.openFirewall`](#servicesedcbopenfirewall)
- [`services.edcb.plugins`](#servicesedcbplugins)
- [`services.edcb.plugins.*.name`](#servicesedcbpluginsname)
- [`services.edcb.plugins.*.pluginPath`](#servicesedcbpluginspluginpath)
- [`services.edcb.plugins.*.settings`](#servicesedcbpluginssettings)
- [`services.edcb.plugins.*.settingsFile`](#servicesedcbpluginssettingsfile)
- [`services.edcb.recordingDir`](#servicesedcbrecordingdir)
- [`services.edcb.recordingGroup`](#servicesedcbrecordinggroup)
- [`services.edcb.settings`](#servicesedcbsettings)
- [`services.edcb.settingsFile`](#servicesedcbsettingsfile)
- [`services.edcb.settingsImmutable`](#servicesedcbsettingsimmutable)
- [`services.edcb.tcpPort`](#servicesedcbtcpport)
- [`services.konomitv.enable`](#serviceskonomitvenable)
- [`services.konomitv.backend`](#serviceskonomitvbackend)
- [`services.konomitv.captureDir`](#serviceskonomitvcapturedir)
- [`services.konomitv.dataDir`](#serviceskonomitvdatadir)
- [`services.konomitv.devices`](#serviceskonomitvdevices)
- [`services.konomitv.edcbHost`](#serviceskonomitvedcbhost)
- [`services.konomitv.edcbPort`](#serviceskonomitvedcbport)
- [`services.konomitv.encoder`](#serviceskonomitvencoder)
- [`services.konomitv.extraSettings`](#serviceskonomitvextrasettings)
- [`services.konomitv.image`](#serviceskonomitvimage)
- [`services.konomitv.logDir`](#serviceskonomitvlogdir)
- [`services.konomitv.manageCaptureDirs`](#serviceskonomitvmanagecapturedirs)
- [`services.konomitv.mirakurunHost`](#serviceskonomitvmirakurunhost)
- [`services.konomitv.mirakurunPort`](#serviceskonomitvmirakurunport)
- [`services.konomitv.openFirewall`](#serviceskonomitvopenfirewall)
- [`services.konomitv.recordingDir`](#serviceskonomitvrecordingdir)
- [`services.konomitv.serverPort`](#serviceskonomitvserverport)
- [`services.konomitv.streamFromMirakurun`](#serviceskonomitvstreamfrommirakurun)
- [`services.mirakurun.enable`](#servicesmirakurunenable)
- [`services.mirakurun.package`](#servicesmirakurunpackage)
- [`services.mirakurun.allowSmartCardAccess`](#servicesmirakurunallowsmartcardaccess)
- [`services.mirakurun.channelSettings`](#servicesmirakurunchannelsettings)
- [`services.mirakurun.openFirewall`](#servicesmirakurunopenfirewall)
- [`services.mirakurun.port`](#servicesmirakurunport)
- [`services.mirakurun.serverSettings`](#servicesmirakurunserversettings)
- [`services.mirakurun.tunerCommandPackages`](#servicesmirakuruntunercommandpackages)
- [`services.mirakurun.tunerSettings`](#servicesmirakuruntunersettings)
- [`services.mirakurun.unixSocket`](#servicesmirakurununixsocket)

## hardware\.px4_drv\.enable

Whether to enable Unofficial Linux Driver for PLEX and e-Better ISDB-T/S Tuner\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv/px4_drv\.nix](../modules/dtv/px4_drv.nix)



## hardware\.px4_drv\.package



px4_drv built for the configured NixOS kernel\.



*Type:*
package



*Default:*

```nix
config.boot.kernelPackages.px4_drv
```

*Declared by:*
 - [modules/dtv/px4_drv\.nix](../modules/dtv/px4_drv.nix)



## services\.dtv\.enable



Whether to enable the integrated Japanese DTV stack\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.edcb\.enable



Whether to enable EDCB as part of the DTV stack\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.konomitv\.enable



Whether to enable KonomiTV as part of the DTV stack\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.mirakurun\.enable



Whether to enable Mirakurun as part of the DTV stack\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.openFirewall



Open firewall ports to access each service externally\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.px4_drv\.enable



Whether to enable px4_drv as part of the DTV stack\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.recordingDir



Shared recording directories\.



*Type:*
list of string



*Default:*

```nix
[
  "/mnt/tv/recordings"
]
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.dtv\.recordingGroup



Group allowed to write recordings\.



*Type:*
string



*Default:*

```nix
"dtv"
```

*Declared by:*
 - [modules/dtv](../modules/dtv)



## services\.edcb\.enable



Whether to enable Linux-native EDCB EpgTimerSrv\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.package



EDCB package to run\.



*Type:*
package



*Default:*

```nix
pkgs.edcb
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.allowSmartCardAccess



Install polkit rules to allow EDCB to access smart card readers
which is commonly used along with tuner devices\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.bondriver



BonDriver definitions to install in selection order\. Their names populate TVTEST in EpgTimerSrv\.ini\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.bondriver\.\*\.driverPath



Absolute path to the BonDriver shared library, normally inside the Nix store\.



*Type:*
string

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.bondriver\.\*\.name



Filename used for the BonDriver library symlink\. The adjacent read-only INI bind mount uses \<name>\.ini inside the EDCB service\. Defaults to the basename of driverPath\.



*Type:*
string



*Default:*

```nix
builtins.baseNameOf driverPath
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.bondriver\.\*\.settings



INI settings bind mounted read-only beside the selected driver as \<name>\.ini inside the EDCB service\. Used when settingsFile is null; null leaves the INI unmanaged if settingsFile is also null\. No driver-specific values are added\.



*Type:*
null or (attribute set of section of an INI file (attrs of INI atom (null, bool, int, float or string)))



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.bondriver\.\*\.settingsFile



Existing INI file to bind mount read-only beside the selected driver as \<name>\.ini inside the EDCB service\. Takes precedence over settings\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.bondriver\.\*\.tunerSettings



Settings written to the section named after this BonDriver in EpgTimerSrv\.ini\. No tuner values are added automatically\.



*Type:*
attribute set of (string or signed integer or boolean)



*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.commonSettings



Managed Common\.ini settings, used when commonSettingsFile is null\. Null leaves the file unmanaged only if commonSettingsFile is also null; a non-null value also receives the recording directory defaults\.



*Type:*
null or (attribute set of section of an INI file (attrs of INI atom (null, bool, int, float or string)))



*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.commonSettingsFile



Existing Common\.ini to use instead of commonSettings, including automatic recording directory settings\. With commonSettingsImmutable, bind mount the file verbatim read-only inside the EDCB service; otherwise merge its values into the writable INI during activation, with source values taking precedence\. Mutable merging does not preserve comments or formatting\. The file is normally stored in the publicly readable Nix store and must not contain secrets\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.commonSettingsImmutable



Read-only bind mount the supplied or generated INI inside the EDCB service\. When false, merge the source settings into the existing writable INI during system activation, with source values taking precedence\. Has no effect when commonSettings and commonSettingsFile are both null\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.epgDataCapBonSettings



Managed EpgDataCap_Bon\.ini settings, used when epgDataCapBonSettingsFile is null\. Null leaves the file unmanaged only if epgDataCapBonSettingsFile is also null\.



*Type:*
null or (attribute set of section of an INI file (attrs of INI atom (null, bool, int, float or string)))



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  SET = {
    SaveDebugLog = 1;
    TraceBonDriverLevel = 2;
    TsBuffMaxCount = 5000;
    WriteBuffMaxCount = -1;
  };
}
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.epgDataCapBonSettingsFile



Existing EpgDataCap_Bon\.ini to use instead of epgDataCapBonSettings\. With epgDataCapBonSettingsImmutable, bind mount the file verbatim read-only inside the EDCB service; otherwise merge its values into the writable INI during activation, with source values taking precedence\. Mutable merging does not preserve comments or formatting\. The file is normally stored in the publicly readable Nix store and must not contain secrets\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.epgDataCapBonSettingsImmutable



Read-only bind mount the supplied or generated INI inside the EDCB service\. When false, merge the source settings into the existing writable INI during system activation, with source values taking precedence\. Has no effect when epgDataCapBonSettings and epgDataCapBonSettingsFile are both null\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.httpPorts



HTTP ports for integrated civetweb\.



*Type:*
list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
[ 5510 ] ++ lib.optional config.services.edcb.materialWebUI.enable 5520
```



*Example:*

```nix
[
  5510
  5520
]
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.httpsPorts



HTTPS ports for integrated civetweb\.



*Type:*
list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
lib.optionals config.services.edcb.materialWebUI.enable [ 5511 5521 ]
```



*Example:*

```nix
[
  5511
  5521
]
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.manageRecordingDirs



Create the recording directories and enforce root ownership, the recording group, and mode 2770\. Disable this for externally managed directories such as NFS shares\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.materialWebUI\.enable



Whether to enable EMWUI 3 for EDCB\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.materialWebUI\.package



EMWUI 3 package to place in EDCB’s HttpPublic and Setting directories\.



*Type:*
package



*Default:*

```nix
pkgs.edcb-material-webui
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.materialWebUI\.extraCertificateSubjectAltNames



Additional OpenSSL subjectAltName entries for the self-signed HTTPS certificate generated on first EDCB startup\. Localhost, 127\.0\.0\.1, and the NixOS host name are included automatically\. Changing this option does not replace an existing certificate\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "DNS:tv.example.com"
  "IP:192.168.1.10"
]
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.openFirewall



Open firewall ports for edcb\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.plugins



Plugin definitions to install in runtime library path\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.plugins\.\*\.name



Filename used for the plugin symlink in /var/lib/edcb/lib\. The read-only INI bind mount uses /var/lib/edcb/\<name>\.ini inside the EDCB service\. Defaults to the basename of pluginPath; must be specified when pluginPath is null\.



*Type:*
string



*Default:*

```nix
builtins.baseNameOf pluginPath
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.plugins\.\*\.pluginPath



Absolute path to the plugin binary, normally inside the Nix store\. Null installs only the INI file\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.plugins\.\*\.settings



INI settings bind mounted read-only as /var/lib/edcb/\<name>\.ini inside the EDCB service\. Used when settingsFile is null; null leaves the INI unmanaged if settingsFile is also null\.



*Type:*
null or (attribute set of section of an INI file (attrs of INI atom (null, bool, int, float or string)))



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.plugins\.\*\.settingsFile



Existing INI file to bind mount read-only as /var/lib/edcb/\<name>\.ini inside the EDCB service\. Takes precedence over settings\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.recordingDir



Directories in which EDCB writes recordings\.



*Type:*
list of string



*Default:*

```nix
[
  "/mnt/tv/recordings"
]
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.recordingGroup



Group with write access to the recording directories\.



*Type:*
string



*Default:*

```nix
"dtv"
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.settings



Managed EpgTimerSrv\.ini settings, used when settingsFile is null\. Null leaves the file unmanaged only if settingsFile is also null\. The option default provides integration settings; an explicit value replaces it\. A non-null value receives TVTEST entries and each BonDriver’s tunerSettings\. For generated settings, TCPPort and HttpPort are always derived from the dedicated port options\.



*Type:*
null or (attribute set of section of an INI file (attrs of INI atom (null, bool, int, float or string)))



*Default:*

```nix
{
  SET = {
    CompatFlags = 128;
    EnableHttpSrv = 1;
    EnableTCPSrv = 1;
    HttpAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
    TCPAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
    TimeSync = 0;
  };
}
```



*Example:*

```nix
{
  EPG_CAP = {
    "0" = "05:15";
    "0BasicOnlyFlags" = 14;
    "0Select" = 1;
    Count = 1;
  };
}
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.settingsFile



Existing EpgTimerSrv\.ini to use instead of settings, including automatic tuner and port settings\. With settingsImmutable, bind mount the file verbatim read-only inside the EDCB service; otherwise merge its values into the writable INI during activation, with source values taking precedence\. Mutable merging does not preserve comments or formatting\. The file is normally stored in the publicly readable Nix store and must not contain secrets\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.settingsImmutable



Read-only bind mount the supplied or generated INI inside the EDCB service\. When false, merge the source settings into the existing writable INI during system activation, with source values taking precedence\. Has no effect when settings and settingsFile are both null\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.edcb\.tcpPort



TCP port for edcb service\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
4510
```



*Example:*

```nix
4510
```

*Declared by:*
 - [modules/dtv/edcb\.nix](../modules/dtv/edcb.nix)



## services\.konomitv\.enable



Whether to enable KonomiTV OCI container\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.backend



Tuner backend application\.



*Type:*
one of “EDCB”, “Mirakurun”



*Default:*

```nix
"EDCB"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.captureDir



Writable capture upload directory\.



*Type:*
list of string



*Default:*

```nix
[
  "/var/lib/konomitv/capture"
]
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.dataDir



Writable KonomiTV data directory\.



*Type:*
string



*Default:*

```nix
"/var/lib/konomitv/data"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.devices



Additional host devices passed to the container, in addition to devices selected by the encoder option\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "/dev/video0:/dev/video0"
]
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.edcbHost



IP or hostname that EDCB service listens to\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.edcbPort



TCP port that EDCB service listens to\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
4510
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.encoder



Video encoder\.



*Type:*
one of “FFmpeg”, “QSVEncC”, “NVEncC”, “VCEEncC”



*Default:*

```nix
"FFmpeg"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.extraSettings



Additional KonomiTV config\.yaml settings\. Values managed by dedicated options take precedence\.



*Type:*
YAML 1\.1 value



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  general = {
    program_update_interval = 5.0;
  };
  video = {
    exclude_scan_paths = [ ];
  };
}
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.image



Official KonomiTV OCI image\.



*Type:*
string



*Default:*

```nix
"ghcr.io/tsukumijima/konomitv:latest"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.logDir



Writable KonomiTV log directory\.



*Type:*
string



*Default:*

```nix
"/var/lib/konomitv/logs"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.manageCaptureDirs



Create the capture directories and enforce root ownership and mode 0750\. Disable this for externally managed directories such as NFS shares\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.mirakurunHost



IP or hostname that mirakurun service listens to\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.mirakurunPort



HTTP port that mirakurun service listens to\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
40772
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.openFirewall



Open firewall port for konomitv\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.recordingDir



Host recording directories, mounted read-only\.



*Type:*
list of string



*Default:*

```nix
[
  "/mnt/tv/recordings"
]
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.serverPort



Server port konomitv listens on\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
7000
```



*Example:*

```nix
7000
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.konomitv\.streamFromMirakurun



Use mirakurun as stream backend instead of EDCB\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [modules/dtv/konomitv\.nix](../modules/dtv/konomitv.nix)



## services\.mirakurun\.enable



Whether to enable the Mirakurun DVR Tuner Server\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.package



Mirakurun package used by the nixpkgs service module\.



*Type:*
package



*Default:*

```nix
pkgs.callPackage ../../pkgs/mirakurun { }
```

*Declared by:*
 - [modules/dtv/mirakurun\.nix](../modules/dtv/mirakurun.nix)



## services\.mirakurun\.allowSmartCardAccess



Install polkit rules to allow Mirakurun to access smart card readers
which is commonly used along with tuner devices\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.channelSettings



Options which are added to channels\.yml\. If none is specified, it
will automatically be generated at runtime\.

Documentation:
[https://github\.com/Chinachu/Mirakurun/blob/master/doc/Configuration\.md](https://github\.com/Chinachu/Mirakurun/blob/master/doc/Configuration\.md)



*Type:*
null or YAML 1\.1 value



*Default:*

```nix
null
```



*Example:*

```nix
[
  {
    name = "channel";
    types = "GR";
    channel = "0";
  }
];

```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.openFirewall



Open ports in the firewall for Mirakurun\.

**Warning:** Exposing Mirakurun to the open internet is generally advised
against\. Only use it inside a trusted local network, or
consider putting it behind a VPN if you want remote access\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.port



Port to listen on\. If ` null `, it won’t listen on
any port\.



*Type:*
null or 16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
40772
```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.serverSettings



Options for server\.yml\.

Documentation:
[https://github\.com/Chinachu/Mirakurun/blob/master/doc/Configuration\.md](https://github\.com/Chinachu/Mirakurun/blob/master/doc/Configuration\.md)



*Type:*
YAML 1\.1 value



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  highWaterMark = 25165824;
  overflowTimeLimit = 30000;
};

```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.tunerCommandPackages



Packages containing tuner commands referenced by tuners\.yml\.



*Type:*
list of package



*Default:*

```nix
[ pkgs.recisdb ]
```

*Declared by:*
 - [modules/dtv/mirakurun\.nix](../modules/dtv/mirakurun.nix)



## services\.mirakurun\.tunerSettings



Options which are added to tuners\.yml\. If none is specified, it will
automatically be generated at runtime\.

Documentation:
[https://github\.com/Chinachu/Mirakurun/blob/master/doc/Configuration\.md](https://github\.com/Chinachu/Mirakurun/blob/master/doc/Configuration\.md)



*Type:*
null or YAML 1\.1 value



*Default:*

```nix
null
```



*Example:*

```nix
[
  {
    name = "tuner-name";
    types = [ "GR" "BS" "CS" "SKY" ];
    dvbDevicePath = "/dev/dvb/adapterX/dvrX";
  }
];

```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)



## services\.mirakurun\.unixSocket



Path to unix socket to listen on\. If ` null `, it
won’t listen on any unix sockets\.



*Type:*
null or absolute path



*Default:*

```nix
"/var/run/mirakurun/mirakurun.sock"
```

*Declared by:*
 - [nixpkgs/nixos/modules/services/video/mirakurun\.nix](https://github.com/NixOS/nixpkgs/blob/dc5d91f840324650bac8c379428c7037a416959a/nixos/modules/services/video/mirakurun.nix)


