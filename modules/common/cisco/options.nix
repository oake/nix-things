{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  cfg = config.services.cisco;

  # Keep the Cisco-specific renderer explicit, but use nixpkgs' XML escaping so
  # values cannot inject elements or attributes.
  escapeXML = value: lib.escapeXML (toString value);
  element = name: value: "<${name}>${escapeXML value}</${name}>";
  boolElement = name: value: element name (if value then "true" else "false");
  optionalElement = name: value: optionalString (value != null) (element name value);
  optionalBoolElement = name: value: optionalString (value != null) (boolElement name value);
  block = name: body: "<${name}>${body}</${name}>";
  attrsBlock =
    name: attrs: body:
    "<${name}${
      concatMapStringsSep "" (a: " ${a.name}=\"${escapeXML a.value}\"") attrs
    }>${body}</${name}>";
  selfClosing =
    name: attrs: "<${name}${concatMapStringsSep "" (a: " ${a.name}=\"${escapeXML a.value}\"") attrs}/>";
  lines = xs: concatStringsSep "\n" xs;

  boolOption =
    default: description:
    mkOption {
      type = types.bool;
      inherit default description;
    };
  nullableBoolOption =
    description:
    mkOption {
      type = types.nullOr types.bool;
      default = null;
      inherit description;
    };
  stringOption =
    default: description:
    mkOption {
      type = types.str;
      inherit default description;
    };
  nullableStringOption =
    description:
    mkOption {
      type = types.nullOr types.str;
      default = null;
      inherit description;
    };
  intOption =
    default: description:
    mkOption {
      type = types.int;
      inherit default description;
    };
  nullableIntOption =
    description:
    mkOption {
      type = types.nullOr types.int;
      default = null;
      inherit description;
    };
  portOption =
    default: description:
    mkOption {
      type = types.ints.between 1 65535;
      inherit default description;
    };
  nullablePortOption =
    description:
    mkOption {
      type = types.nullOr (types.ints.between 1 65535);
      default = null;
      inherit description;
    };
  nullableEnumOption =
    values: description:
    mkOption {
      type = types.nullOr (types.enum values);
      default = null;
      inherit description;
    };
  optional01Element =
    name: value: optionalString (value != null) (element name (if value then 1 else 0));

  ntpType = types.submodule (_: {
    options = {
      name = stringOption "" "IPv4 address or DNS name of the NTP server.";
    };
  });

  callManagerType = types.submodule (_: {
    options = {
      address = stringOption "" "SIP registrar/proxy address used by USECALLMANAGER.";
      sipPort = portOption 5060 "Plain SIP destination port.";
      securedSipPort = nullablePortOption "TLS SIP destination port; omit when TLS is unused.";
    };
  });

  forwardDisplayType = types.submodule (_: {
    options = {
      callerName = boolOption true "Display the caller name.";
      callerNumber = boolOption true "Display the caller number.";
      redirectedNumber = boolOption true "Display the redirecting number.";
      dialedNumber = boolOption true "Display the originally dialed number.";
    };
  });

  buttonKinds = [
    "line"
    "intercom"
    "redial"
    "speed-dial"
    "hold"
    "transfer"
    "call-forward-all"
    "settings"
    "service-url"
    "blf-speed-dial"
    "blf-directed-park"
    "malicious-call"
    "conference"
    "meet-me"
    "park"
    "pickup"
    "group-pickup"
    "dnd"
    "remove-last-conference-participant"
    "report-quality"
    "callback"
    "other-pickup"
    "new-call"
    "hunt-login"
    "answer"
    "record"
    "services"
    "messages"
    "directories"
    "applications"
    "headset"
  ];

  buttonFeatureIDs = {
    line = 9;
    intercom = 23;
    redial = 1;
    speed-dial = 2;
    hold = 3;
    transfer = 4;
    call-forward-all = 5;
    settings = 18;
    service-url = 20;
    blf-speed-dial = 21;
    blf-directed-park = 22;
    malicious-call = 27;
    conference = 102;
    meet-me = 123;
    park = 126;
    pickup = 127;
    group-pickup = 128;
    dnd = 130;
    remove-last-conference-participant = 132;
    report-quality = 133;
    callback = 134;
    other-pickup = 135;
    new-call = 137;
    hunt-login = 139;
    answer = 141;
    record = 159;
    services = 192;
    messages = 194;
    directories = 195;
    applications = 197;
    headset = 198;
  };

  buttonType = types.submodule (_: {
    options = {
      button = mkOption {
        type = types.ints.positive;
        description = "Physical button number: 1-8 on the base phone, continuing on declared expansion modules.";
      };
      kind = mkOption {
        type = types.enum buttonKinds;
        description = "7975G-supported button function. The firmware featureID is derived from this value.";
      };
      label = stringOption "" "Label shown beside the button.";
      lineIndex = nullableIntOption "Logical line index, required for line and intercom buttons.";
      proxy = stringOption "USECALLMANAGER" "Proxy selector for line/intercom buttons.";
      port = portOption 5060 "Registrar port for line/intercom buttons.";
      name = stringOption "" "SIP address-of-record user for a line/intercom button.";
      displayName = stringOption "" "Display identity for a line/intercom button.";
      autoAnswer = mkOption {
        type = types.enum [
          "disabled"
          "speakerphone"
        ];
        default = "disabled";
        description = "Verified line auto-answer modes (serialized as 0 or 3).";
      };
      callWaiting = mkOption {
        type = types.enum [
          "enabled"
          "line-policy"
        ];
        default = "line-policy";
        description = "Call waiting behavior (verified encodings 1 and 3).";
      };
      authName = stringOption "" "SIP digest username; normally required only on the primary line.";
      authPassword = stringOption "" ''
        SIP digest password. WARNING: rendering this option through Nix puts the
        plaintext secret in the Nix store if the rendered value is realized.
      '';
      contact = stringOption "" ''
        Optional SIP Contact user for this appearance. When empty, the phone uses
        name on a line or speedDialNumber on a BLF button.
      '';
      sharedLine = boolOption false "Mark this as a shared line; requires PBX support.";
      messageWaitingLampPolicy = mkOption {
        type = types.enum [
          "disabled"
          "primary-line"
          "light-and-prompt"
          "use-line-policy"
        ];
        default = "use-line-policy";
        description = "MWI lamp policy, serialized as the verified 0-3 enum.";
      };
      audibleMessageWaiting = boolOption false "Enable audible message-waiting indication.";
      messagesNumber = stringOption "" "Number dialed by the Messages key for this line.";
      ringWhenIdle = mkOption {
        type = types.ints.between 0 5;
        default = 4;
        description = "CUCM 7975G ring-setting enum while idle; 4 is the usual system/default policy.";
      };
      ringWhenActive = mkOption {
        type = types.ints.between 0 5;
        default = 5;
        description = "CUCM 7975G ring-setting enum while another call is active.";
      };
      forwardCallInfoDisplay = mkOption {
        type = forwardDisplayType;
        default = { };
        description = "Fields displayed for forwarded calls.";
      };
      maxNumCalls = mkOption {
        type = types.ints.positive;
        default = 5;
        description = "Maximum calls represented on the line.";
      };
      busyTrigger = mkOption {
        type = types.ints.positive;
        default = 4;
        description = "Call count at which the line becomes busy; must not exceed maxNumCalls.";
      };
      recording = boolOption true "Allow recording UI/stream duplication when the PBX supports it.";
      speedDialNumber = nullableStringOption "Number for speed-dial, BLF, or directed-park buttons.";
      featureOptionMask = mkOption {
        type = types.enum [
          "presence-only"
          "presence-ringing-and-pickup"
        ];
        default = "presence-ringing-and-pickup";
        description = "BLF behavior; the latter serializes featureOptionMask 1.";
      };
      retrievalPrefix = stringOption "" "Prefix dialed when retrieving a directed parked call.";
      serviceURI = nullableStringOption "HTTP service URL for a service-url button.";
      secureServiceURI = nullableStringOption "HTTPS service URL for a service-url button.";
    };
  });

  addOnModuleType = types.submodule (_: {
    options = {
      index = mkOption {
        type = types.ints.between 1 2;
        description = "Physical expansion-module position.";
      };
      deviceType = mkOption {
        type = types.enum [
          "7915"
          "7916"
        ];
        description = "Supported expansion module.";
      };
      deviceLine = mkOption {
        type = types.ints.positive;
        default = 24;
        description = "Number of keys on the module.";
      };
      loadInformation = stringOption "" "Expansion-module firmware load ID.";
    };
  });

  phoneServiceType = types.submodule (_: {
    options = {
      type = mkOption {
        type = types.enum [
          "application"
          "voicemail"
        ];
        default = "application";
        description = "Verified built-in service type.";
      };
      category = mkOption {
        type = types.enum [ "default" ];
        default = "default";
        description = "Verified category 0.";
      };
      name = stringOption "" "Service display name.";
      url = stringOption "" "Application:Cisco URI or Cisco IP Phone XML-service URL.";
      vendor = stringOption "" "Optional service vendor metadata.";
      version = stringOption "" "Optional service version metadata.";
    };
  });

  dialToneNames = [
    "Bellcore-Inside"
    "Bellcore-Outside"
    "Bellcore-Busy"
    "Bellcore-Reorder"
    "Bellcore-CallWaiting"
    "Bellcore-Hold"
    "Bellcore-Reminder"
    "Bellcore-Confirmation"
    "Bellcore-Permanent"
    "Bellcore-None"
    "Cisco-Zip"
    "Cisco-ZipZip"
    "Cisco-BeepBonk"
  ];

  dialTemplateType = types.submodule (_: {
    options = {
      match = stringOption "" "Cisco dial-pattern expression.";
      timeout = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = "Seconds to wait after this pattern matches before dialing.";
      };
      line = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Optional logical line index to which this template applies.";
      };
      rewrite = nullableStringOption "Optional replacement expression for the matched number.";
      user = mkOption {
        type = types.nullOr (types.enum [ "Phone" ]);
        default = null;
        description = "Optional originator filter; Phone restricts the template to on-phone dialing.";
      };
      tones = mkOption {
        type = types.listOf (types.enum dialToneNames);
        default = [ ];
        description = "Up to three secondary dial tones, in playback order.";
      };
    };
  });

  dialPlanType = types.submodule (_: {
    options = {
      templates = mkOption {
        type = types.nonEmptyListOf dialTemplateType;
        description = "Ordered dial templates; specific patterns should precede catch-alls.";
      };
    };
  });

  softKeyDefinitions = {
    Undefined = {
      tag = 0;
      eventID = 0;
      helpID = 0;
    };
    Null = {
      tag = 0;
      eventID = 0;
      helpID = 0;
    };
    Redial = {
      tag = 1;
      eventID = 1;
      helpID = 301;
    };
    NewCall = {
      tag = 2;
      eventID = 2;
      helpID = 302;
    };
    Hold = {
      tag = 3;
      eventID = 3;
      helpID = 303;
    };
    Transfer = {
      tag = 4;
      eventID = 4;
      helpID = 304;
    };
    CFwdAll = {
      tag = 5;
      eventID = 5;
      helpID = 305;
    };
    "<<" = {
      tag = 8;
      eventID = 8;
      helpID = 308;
    };
    EndCall = {
      tag = 9;
      eventID = 9;
      helpID = 309;
    };
    Resume = {
      tag = 10;
      eventID = 10;
      helpID = 310;
    };
    Answer = {
      tag = 11;
      eventID = 11;
      helpID = 311;
    };
    Confrn = {
      tag = 13;
      eventID = 13;
      helpID = 313;
    };
    Park = {
      tag = 14;
      eventID = 14;
      helpID = 314;
    };
    Join = {
      tag = 15;
      eventID = 15;
      helpID = 315;
    };
    MeetMe = {
      tag = 16;
      eventID = 16;
      helpID = 316;
    };
    PickUp = {
      tag = 17;
      eventID = 17;
      helpID = 317;
    };
    GPickUp = {
      tag = 18;
      eventID = 18;
      helpID = 318;
    };
    RmLstC = {
      tag = 57;
      eventID = 19;
      helpID = 319;
    };
    CallBack = {
      tag = 65;
      eventID = 20;
      helpID = 320;
    };
    DND = {
      tag = 63;
      eventID = 69;
      helpID = 369;
    };
    QRT = {
      tag = 75;
      eventID = 22;
      helpID = 322;
    };
    MCID = {
      tag = 76;
      eventID = 27;
      helpID = 327;
    };
    Select = {
      tag = 78;
      eventID = 29;
      helpID = 329;
    };
    ConfList = {
      tag = 79;
      eventID = 30;
      helpID = 330;
    };
    iDivert = {
      tag = 80;
      eventID = 31;
      helpID = 331;
    };
    OPickUp = {
      tag = 91;
      eventID = 34;
      helpID = 334;
    };
    HLog = {
      tag = 92;
      eventID = 35;
      helpID = 335;
    };
    AbbrDial = {
      tag = 7740;
      eventID = 71;
      helpID = 371;
    };
    Record = {
      tag = 7747;
      eventID = 74;
      helpID = 374;
    };
  };

  softKeyStateNames = [
    "On Hook"
    "Off Hook"
    "Off Hook With Feature"
    "Digits After First"
    "Ring Out"
    "Ring In"
    "Connected"
    "Connected No Feature"
    "Connected Transfer"
    "Connected Conference"
    "On Hold"
    "Remote In Use"
    "On Hook With Feature"
  ];

  softKeysType = types.submodule (_: {
    options = lib.genAttrs softKeyStateNames (
      state:
      mkOption {
        type = types.nullOr (types.listOf (types.enum (builtins.attrNames softKeyDefinitions)));
        default = null;
        description = "Softkeys shown in the ${state} call state, in display order (maximum 16). Unset to omit this state.";
      }
    );
  });

  srstType = types.submodule (_: {
    options = {
      enabled = boolOption false "Enable CUCM Survivable Remote Site Telephony data.";
      addresses = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Up to three SRST SIP addresses.";
      };
      ports = mkOption {
        type = types.listOf (types.ints.between 1 65535);
        default = [ ];
        description = "SRST SIP ports corresponding to addresses.";
      };
      secure = boolOption false "Use secure SRST signaling.";
    };
  });

  deviceType = types.submodule (_: {
    options = {
      macAddress = mkOption {
        type = types.strMatching "[0-9A-F]{12}";
        description = "Twelve uppercase hexadecimal digits used in SEP<MAC>.cnf.xml.";
        example = "002584A38153";
      };
      ipAddressMode = mkOption {
        type = types.enum [
          "ipv4"
          "ipv6"
          "dual-stack"
        ];
        default = "ipv4";
        description = "Phone address-family mode.";
      };
      allowAutoConfig = boolOption true "Allow automatic network configuration.";
      duplicateAddressDetection = boolOption true "Enable IPv6 duplicate-address detection.";
      acceptIcmpRedirects = boolOption false "Accept/use ICMP redirects.";
      respondToMulticastEcho = boolOption false "Respond to multicast ICMP echo.";

      dateTime = {
        dateTemplate = mkOption {
          type = types.enum [
            "D/M/Y"
            "D-M-YY"
            "M/D/YA"
            "M/D/Y"
            "Y-M-D"
          ];
          default = "D-M-YY";
          description = "7975G date display template.";
        };
        timeZone = stringOption "W. Europe Standard/Daylight Time" "Cisco time-zone label, not an IANA identifier.";
        ntpServers = mkOption {
          type = types.listOf ntpType;
          default = [ { name = "191.96.11.19"; } ];
          description = "NTP servers.";
        };
      };
      callManagers = mkOption {
        type = types.nonEmptyListOf callManagerType;
        description = "Ordered SIP registrars; the first entry is primary and the rest are failover backups.";
      };
      connectionMonitorDuration = nullableIntOption "CUCM/SRST connection-monitor interval in seconds.";
      srst = mkOption {
        type = srstType;
        default = { };
        description = "Optional CUCM SRST data.";
      };

      sip = {
        registerWithProxy = boolOption true "Register SIP lines with the selected proxy.";
        callFeatures = {
          conferenceJoin = boolOption true "Enable conference/select/join UI.";
          callForwardURI = stringOption "x-cisco-serviceuri-cfwdall" "Forward-all service URI.";
          callPickupURI = stringOption "x-cisco-serviceuri-pickup" "Pickup service URI.";
          otherPickupURI = stringOption "x-cisco-serviceuri-opickup" "Other-group pickup service URI.";
          groupPickupURI = stringOption "x-cisco-serviceuri-gpickup" "Group pickup service URI.";
          meetMeURI = stringOption "x-cisco-serviceuri-meetme" "Meet-Me service URI.";
          abbreviatedDialURI = stringOption "x-cisco-serviceuri-abbrdial" "Abbreviated-dial service URI.";
          holdStyle = nullableEnumOption [
            "rfc3264"
            "rfc2543"
          ] "SIP hold signaling style.";
          callHoldRingback = nullableBoolOption "Enable hold ringback/reminder behavior.";
          localCallForward = nullableBoolOption "Enable local Forward All UI.";
          semiAttendedTransfer = nullableBoolOption "Allow transfer completion while the target rings.";
          anonymousCallBlock = nullableBoolOption "Enable local anonymous-call blocking.";
          callerIdBlocking = nullableBoolOption "Enable caller-ID blocking UI.";
          dndControl = nullableEnumOption [
            "disabled"
            "reject"
            "ringer-off"
          ] "Do Not Disturb policy.";
          remoteCallControl = boolOption true "Enable Cisco remote call-control signaling.";
          retainForwardInformation = boolOption true "Retain forwarding information from call control.";
          uriDisplay = nullableEnumOption [
            "uri"
            "number-first"
          ] "SIP URI display preference.";
        };
        stack = {
          inviteRetransmissions = intOption 6 "Maximum INVITE retransmissions.";
          nonInviteRetransmissions = intOption 10 "Maximum non-INVITE retransmissions.";
          inviteExpires = intOption 180 "INVITE expiry in seconds.";
          registerExpires = intOption 3600 "Requested registration lifetime in seconds.";
          registerDelta = intOption 5 "Seconds before expiry at which registration renews.";
          keepAliveExpires = intOption 120 "Keepalive interval/expiry in seconds.";
          subscribeExpires = intOption 120 "Requested subscription lifetime in seconds.";
          subscribeDelta = intOption 5 "Seconds before expiry at which subscriptions renew.";
          t1 = intOption 500 "RFC 3261 T1 in milliseconds.";
          t2 = intOption 4000 "RFC 3261 T2 in milliseconds.";
          maxRedirects = intOption 70 "Maximum followed SIP redirects.";
          remotePartyId = boolOption true "Enable legacy Remote-Party-ID handling.";
          numericUserInfo = boolOption true "Append/treat numeric SIP identities as user=phone.";
        };
        autoAnswerTimer = nullableIntOption "Auto-answer delay in seconds.";
        autoAnswerAlternateBehavior = nullableBoolOption "Use alternate auto-answer behavior.";
        autoAnswerOverride = nullableBoolOption "Allow line auto-answer to override profile behavior.";
        transferOnHook = nullableBoolOption "Complete transfer by replacing the handset.";
        voiceActivityDetection = nullableBoolOption "Enable VAD/silence suppression.";
        preferredCodec = nullableEnumOption [
          "none"
          "g711ulaw"
          "g711alaw"
          "g722"
          "g729a"
        ] "Preferred audio codec.";
        dtmf = mkOption {
          type = types.nullOr (
            types.submodule (_: {
              options = {
                payload = mkOption {
                  type = types.ints.between 96 127;
                  default = 101;
                  description = "RTP telephone-event payload type.";
                };
                dbLevel = mkOption {
                  type = types.ints.between 0 3;
                  default = 3;
                  description = "Telephone-event volume field.";
                };
                transport = mkOption {
                  type = types.enum [ "avt" ];
                  default = "avt";
                  description = "Verified RTP-event transport.";
                };
              };
            })
          );
          default = null;
          description = "RTP telephone-event settings. Omit to use the phone firmware defaults.";
        };
        alwaysUsePrimeLine = nullableBoolOption "Select the primary line on off-hook.";
        alwaysUsePrimeLineForVoiceMail = nullableBoolOption "Use the primary line for the Messages key.";
        kpml = boolOption false "Enable Key Press Markup Language digit reporting.";
        phoneLabel = stringOption "" "Idle-screen phone label.";
        stutterMessageWaiting = nullableBoolOption "Enable stutter dial tone for MWI.";
        callStats = nullableBoolOption "Enable RTP/QRT call statistics.";
        offHookToFirstDigitTimer = nullableIntOption "First-digit timeout in milliseconds.";
        callWaitingBurstSilence = nullableIntOption "Seconds between call-waiting tone bursts.";
        disableLocalSpeedDialConfig = nullableBoolOption "Prevent local speed-dial editing.";
        mediaPorts = mkOption {
          type = types.nullOr (
            types.submodule (_: {
              options = {
                first = portOption 16384 "First RTP UDP port.";
                last = portOption 32766 "Last RTP UDP port.";
              };
            })
          );
          default = null;
          description = "RTP UDP port range. Omit to use the phone firmware defaults.";
        };
        nat = {
          enabled = boolOption false "Enable static phone-side NAT handling.";
          receivedProcessing = boolOption false "Use received/rport NAT processing.";
          address = nullableStringOption "Static public address; required only when NAT is enabled.";
        };
        buttons = mkOption {
          type = types.nonEmptyListOf buttonType;
          description = "SIP lines and supported programmable-button assignments.";
        };
        externalNumberMask = nullableStringOption "Optional presentation mask.";
        localPort = portOption 5060 "Local SIP signaling port.";
        dscpForAudio = mkOption {
          type = types.nullOr (types.ints.between 0 255);
          default = null;
          description = "Full IPv4 DS/TOS byte; 184 represents DSCP EF. Omit for the phone default.";
        };
        busyStationRingPolicy = nullableEnumOption [ "system" ] "Verified external-PBX encoding 0.";
        dialPlan = mkOption {
          type = types.nullOr dialPlanType;
          default = null;
          description = "Dial plan rendered to a separate, automatically referenced XML file.";
        };
        softKeys = mkOption {
          type = types.nullOr softKeysType;
          default = null;
          description = ''
            Softkey layout rendered to a separate, automatically referenced XML file.
            Keys are the Cisco call state; values are the softkeys shown in that state,
            in display order.
          '';
        };
      };

      missedCallLogging = nullableBoolOption "Enable or disable missed-call logging.";
      commonProfile = {
        phonePassword = stringOption "" "Password used to unlock protected phone settings.";
        callLogBlf = nullableEnumOption [
          "disabled"
          "enabled"
          "call-lists"
          "directories-and-call-lists"
        ] "BLF state display scope in call logs/directories.";
      };

      wallpaperFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          A 320x216 PNG image forced as this phone's wallpaper. The module
          generates the thumbnail and Cisco image-list XML automatically.
        '';
      };
      vendor = {
        disableSpeaker = boolOption false "Disable speakerphone.";
        disableSpeakerAndHeadset = boolOption false "Disable both speakerphone and headset.";
        pcPort = nullableBoolOption "Enable the rear PC Ethernet port.";
        settingsAccess = nullableEnumOption [
          "disabled"
          "enabled"
          "restricted"
        ] "Access to Settings menus.";
        gratuitousArp = nullableBoolOption "Enable Gratuitous ARP learning behavior.";
        voiceVlanAccess = nullableBoolOption "Permit the PC-port device on the voice VLAN.";
        spanToPcPort = nullableBoolOption "Mirror phone traffic to the PC port.";
        loggingDisplay = nullableBoolOption "Enable TAC diagnostic logging display.";
        electronicHookswitch = nullableBoolOption "Enable wireless-headset EHS control.";
        autoSelectLine = nullableBoolOption "Move focus to incoming calls on other lines.";
        rtcp = nullableBoolOption "Enable RTCP, including during SIP hold.";
        dontFragment = nullableBoolOption "Set the IPv4 Don't Fragment bit.";
        webAccess = boolOption true "Enable phone status web pages.";
        webProtocol = mkOption {
          type = types.enum [
            "http-and-https"
            "https-only"
          ];
          default = "http-and-https";
          description = "Phone status web-server protocol.";
        };
        sshAccess = boolOption false "Enable the phone SSH server.";
        loadServer = nullableStringOption "Alternate server for firmware load files.";
        peerFirmwareSharing = nullableBoolOption "Allow peer firmware sharing.";
        cdpSwitchPort = nullableBoolOption "Enable CDP on the switch port.";
        cdpPcPort = nullableBoolOption "Enable CDP on the PC port.";
        lldpSwitchPort = nullableBoolOption "Enable LLDP-MED on the switch port.";
        lldpPcPort = nullableBoolOption "Enable LLDP on the PC port.";
        powerNegotiation = nullableBoolOption "Enable CDP/LLDP power negotiation.";
        g722 = mkOption {
          type = types.enum [
            "disabled"
            "system"
            "enabled"
          ];
          default = "enabled";
          description = "G.722 codec capability policy.";
        };
        handsetWideband = mkOption {
          type = types.enum [
            "disabled"
            "enabled"
            "user-controlled"
          ];
          default = "enabled";
          description = "Handset wideband mode.";
        };
        headsetWideband = mkOption {
          type = types.enum [
            "disabled"
            "enabled"
            "user-controlled"
          ];
          default = "enabled";
          description = "Headset wideband mode.";
        };
        handsetWidebandUiControl = boolOption true "Allow user control of handset wideband mode.";
        headsetWidebandUiControl = boolOption true "Allow user control of headset wideband mode.";
        minimumRingVolume = mkOption {
          type = types.nullOr (types.ints.between 0 15);
          default = null;
          description = "Enforced minimum ringer volume.";
        };
        recordingTone = nullableBoolOption "Enable periodic recording notification tone.";
        recordingToneLocalVolume = mkOption {
          type = types.nullOr (types.ints.between 0 100);
          default = null;
          description = "Local recording-tone volume.";
        };
        recordingToneRemoteVolume = mkOption {
          type = types.nullOr (types.ints.between 0 100);
          default = null;
          description = "Remote recording-tone volume.";
        };
        recordingToneDuration = nullableIntOption "Recording-tone duration in milliseconds.";
        moreKeyReversionTimer = nullableIntOption "Seconds before the softkey page returns from More.";
        display = mkOption {
          type = types.nullOr (
            types.submodule (_: {
              options = {
                inactiveDays = mkOption {
                  type = types.listOf (types.ints.between 1 7);
                  default = [
                    1
                    7
                  ];
                  description = "Sunday=1 through Saturday=7.";
                };
                onTime = stringOption "08:00" "Scheduled display-on time (HH:MM).";
                onDuration = stringOption "12:00" "Scheduled display-on duration (HH:MM).";
                idleTimeout = stringOption "00:10" "Display idle timeout (HH:MM).";
                onForIncomingCall = boolOption true "Turn the display on for incoming calls.";
              };
            })
          );
          default = null;
          description = "Display power-save schedule. Omit to use the phone firmware defaults.";
        };
      };

      inactiveLoadInformation = nullableStringOption "Inactive/alternate firmware load ID.";
      addOnModules = mkOption {
        type = types.listOf addOnModuleType;
        default = [ ];
        description = "Attached Cisco 7915/7916 expansion modules.";
      };
      phoneServices = {
        useHTTPS = boolOption false "Use HTTPS for phone-service retrieval.";
        services = mkOption {
          type = types.listOf phoneServiceType;
          default = [ ];
          description = "Built-in or XML phone services.";
        };
      };
      userLocale = mkOption {
        type = types.nullOr (
          types.submodule (_: {
            options = {
              name = stringOption "English_United_States" "Installed Cisco user-locale identifier.";
              uid = intOption 1 "Cisco locale UID.";
              languageCode = stringOption "en_US" "Locale language code.";
              version = stringOption "1.0.0.0-1" "Installed locale version.";
              windowsCharset = stringOption "utf-8" "Locale character-set identifier.";
            };
          })
        );
        default = null;
        description = ''
          User locale. When set, the phone fetches English_United_States/td-sip.jar
          (or the matching locale JAR) from this server. Omit to keep the locale
          already in the phone's flash.
        '';
      };
      networkLocale = mkOption {
        type = types.nullOr (
          types.submodule (_: {
            options = {
              name = stringOption "United_States" "Installed Cisco network-locale identifier.";
              version = stringOption "1.0.0.0-1" "Installed network-locale version.";
            };
          })
        );
        default = null;
        description = ''
          Network locale (tone plan). When set, the phone fetches
          United_States/g3-tones.xml from this server. Omit to keep the
          locale already in the phone's flash.
        '';
      };
      urls = {
        authentication = nullableStringOption "Authentication URL for pushed phone commands.";
        messages = nullableStringOption "Messages XML-service URL.";
        services = nullableStringOption "Services XML-service URL.";
        directory = nullableStringOption "Directories XML-service URL.";
        idle = nullableStringOption "Idle XML-service URL.";
        information = nullableStringOption "Information XML-service URL.";
        proxy = nullableStringOption "HTTP proxy URL used for XML services.";
        secureAuthentication = nullableStringOption "Secure authentication URL.";
        secureMessages = nullableStringOption "Secure messages URL.";
        secureServices = nullableStringOption "Secure services URL.";
        secureDirectory = nullableStringOption "Secure directory URL.";
        secureIdle = nullableStringOption "Secure idle URL.";
        secureInformation = nullableStringOption "Secure information URL.";
      };
      idleTimeout = nullableIntOption "Seconds before the idle XML service is opened; 0 disables.";
      transport = mkOption {
        type = types.enum [
          "udp"
          "tcp"
          "tls"
        ];
        default = "udp";
        description = "SIP transport.";
      };
      tlsResumptionTimer = nullableIntOption "TLS session-resumption lifetime in seconds.";
      phonePersonalization = nullableBoolOption "Enable phone personalization controls.";
      autoCallPickup = nullableBoolOption "Enable automatic call pickup.";
      blfAudibleAlertWhenIdle = nullableBoolOption "Enable a BLF audible alert while the monitored station is idle.";
      blfAudibleAlertWhenBusy = nullableBoolOption "Enable a BLF audible alert while the monitored station is busy.";
      dndCallAlert = mkOption {
        type = types.nullOr (
          types.enum [
            "disabled"
            "beep"
            "flash"
          ]
        );
        default = null;
        description = "DND call-alert policy.";
      };
      dndReminderTimer = nullableIntOption "DND reminder interval in minutes.";
      advertiseG722 = boolOption true "Advertise G.722 in SIP SDP.";
      rollover = nullableBoolOption "Enable call rollover behavior across lines.";
      joinAcrossLines = nullableBoolOption "Allow Join across different line appearances.";
      deviceSecurityMode = nullableEnumOption [
        "non-secure"
        "authenticated"
        "encrypted"
      ] "CUCM device security mode. Omit to leave the phone default.";
      ssh = {
        user = nullableStringOption "SSH user ID; set only when SSH is enabled.";
        password = nullableStringOption "SSH password; plaintext has the same Nix-store warning as authPassword.";
      };
    };
  });

  renderForwardDisplay =
    value:
    block "forwardCallInfoDisplay" (lines [
      (boolElement "callerName" value.callerName)
      (boolElement "callerNumber" value.callerNumber)
      (boolElement "redirectedNumber" value.redirectedNumber)
      (boolElement "dialedNumber" value.dialedNumber)
    ]);

  renderButton =
    value:
    let
      isLine = value.kind == "line" || value.kind == "intercom";
      isBLF = value.kind == "blf-speed-dial" || value.kind == "blf-directed-park";
      attrs = [
        {
          name = "button";
          value = toString value.button;
        }
      ]
      ++ lib.optional isLine {
        name = "lineIndex";
        value = toString value.lineIndex;
      };
      mwiMap = {
        disabled = 0;
        primary-line = 1;
        light-and-prompt = 2;
        use-line-policy = 3;
      };
      autoAnswerCode = if value.autoAnswer == "speakerphone" then 3 else 0;
      autoAnswerMode = if value.autoAnswer == "speakerphone" then "Auto Answer with Speakerphone" else "";
      body = [
        (element "featureID" buttonFeatureIDs.${value.kind})
      ]
      ++ lib.optional (value.label != "") (element "featureLabel" value.label)
      ++ lib.optionals isLine [
        (element "proxy" value.proxy)
        (element "port" value.port)
        (element "name" value.name)
        (element "displayName" value.displayName)
        (block "autoAnswer" (lines [
          (element "autoAnswerEnabled" autoAnswerCode)
          (optionalString (autoAnswerMode != "") (element "autoAnswerMode" autoAnswerMode))
        ]))
        (element "callWaiting" (if value.callWaiting == "enabled" then 1 else 3))
      ]
      ++ lib.optionals (value.kind == "line") [
        (element "authName" value.authName)
        (element "authPassword" value.authPassword)
        (element "contact" value.contact)
        (boolElement "sharedLine" value.sharedLine)
        (element "messageWaitingLampPolicy" mwiMap.${value.messageWaitingLampPolicy})
        (element "messageWaitingAMWI" (if value.audibleMessageWaiting then 1 else 0))
        (element "messagesNumber" value.messagesNumber)
        (element "ringSettingIdle" value.ringWhenIdle)
        (element "ringSettingActive" value.ringWhenActive)
        (renderForwardDisplay value.forwardCallInfoDisplay)
        (element "maxNumCalls" value.maxNumCalls)
        (element "busyTrigger" value.busyTrigger)
        (element "recordingOption" (if value.recording then "enable" else "disable"))
      ]
      ++ lib.optionals (value.kind == "intercom") [
        (element "maxNumCalls" value.maxNumCalls)
        (element "busyTrigger" value.busyTrigger)
      ]
      ++ lib.optional (value.speedDialNumber != null) (element "speedDialNumber" value.speedDialNumber)
      ++ lib.optional (
        value.kind == "blf-speed-dial" && value.featureOptionMask == "presence-ringing-and-pickup"
      ) (element "featureOptionMask" 1)
      ++ lib.optional (isBLF && value.contact != "") (element "contact" value.contact)
      ++ lib.optional (value.kind == "blf-directed-park") (
        element "retrievalPrefix" value.retrievalPrefix
      )
      ++ lib.optional (value.serviceURI != null) (element "serviceURI" value.serviceURI)
      ++ lib.optional (value.secureServiceURI != null) (
        element "secureServiceURI" value.secureServiceURI
      );
    in
    attrsBlock "line" attrs (lines body);

  renderDialPlan =
    dialPlan:
    let
      renderTemplate =
        template:
        selfClosing "TEMPLATE" (
          [
            {
              name = "match";
              value = template.match;
            }
            {
              name = "timeout";
              value = toString template.timeout;
            }
          ]
          ++ lib.optional (template.line != null) {
            name = "line";
            value = toString template.line;
          }
          ++ lib.optional (template.rewrite != null) {
            name = "rewrite";
            value = template.rewrite;
          }
          ++ lib.optional (template.user != null) {
            name = "User";
            value = template.user;
          }
          ++ lib.optional (template.tones != [ ]) {
            name = "tone";
            value = concatStringsSep " " template.tones;
          }
        );
    in
    ''
      <?xml version="1.0" encoding="utf-8"?>
      <dialTemplate>
      ${element "versionStamp" (configHash dialPlan)}
      ${lines (map renderTemplate dialPlan.templates)}
      </dialTemplate>
    '';

  assignedSoftKeyStates =
    softKeys: builtins.filter (state: softKeys.${state} != null) softKeyStateNames;

  renderSoftKeys =
    softKeys:
    let
      states = assignedSoftKeyStates softKeys;
      usedKeys = lib.unique (lib.concatMap (state: softKeys.${state}) states);
      renderDefinition =
        keyID:
        let
          definition = softKeyDefinitions.${keyID};
        in
        attrsBlock "softKeyDef"
          [
            {
              name = "keyID";
              value = keyID;
            }
          ]
          (lines [
            (element "tag" definition.tag)
            (element "eventID" definition.eventID)
            (element "helpID" definition.helpID)
          ]);
      renderSet =
        state:
        attrsBlock "softKeySet"
          [
            {
              name = "id";
              value = state;
            }
          ]
          (
            lines (
              map (
                keyID:
                selfClosing "softKey" [
                  {
                    name = "keyID";
                    value = keyID;
                  }
                ]
              ) softKeys.${state}
            )
          );
    in
    ''
      <?xml version="1.0" encoding="utf-8"?>
      <softKeyCfg>
      ${element "versionStamp" (configHash softKeys)}
      ${block "typeSoftKey" (lines (map renderDefinition usedKeys))}
      ${block "softKeySets" (lines (map renderSet states))}
      </softKeyCfg>
    '';

  configHash = value: builtins.hashString "sha256" (builtins.toJSON value);
  shortHash = value: builtins.substring 0 8 (builtins.hashString "sha256" value);
  shortFileHash = file: builtins.substring 0 8 (builtins.hashFile "sha256" file);
  contentFilename = prefix: contents: "${prefix}-${shortHash contents}.xml";
  dialPlanFilename = dialPlan: contentFilename "dialplan" (renderDialPlan dialPlan);
  softKeysFilename = softKeys: contentFilename "softkeys" (renderSoftKeys softKeys);
  wallpaperDirectory = "Desktops/320x216x16";
  wallpaperFilename = wallpaperFile: "w-${shortFileHash wallpaperFile}.png";
  wallpaperThumbnailFilename = wallpaperFile: "TN-${wallpaperFilename wallpaperFile}";
  ringtoneFilename = file: "r-${shortFileHash file}.raw";

  renderRingList = ringtones: ''
    <?xml version="1.0" encoding="utf-8"?>
    <CiscoIPPhoneRingList>
    ${lines (
      mapAttrsToList (displayName: file: ''
        <Ring>
        ${element "DisplayName" displayName}
        ${element "FileName" (ringtoneFilename file)}
        </Ring>
      '') ringtones
    )}
    </CiscoIPPhoneRingList>
  '';

  renderWallpaperList = wallpaperFiles: ''
    <?xml version="1.0" encoding="utf-8"?>
    <CiscoIPPhoneImageList>
    ${lines (
      map (
        wallpaperFile:
        selfClosing "ImageItem" [
          {
            name = "Image";
            value = "TFTP:${wallpaperDirectory}/${wallpaperThumbnailFilename wallpaperFile}";
          }
          {
            name = "URL";
            value = "TFTP:${wallpaperDirectory}/${wallpaperFilename wallpaperFile}";
          }
        ]
      ) wallpaperFiles
    )}
    </CiscoIPPhoneImageList>
  '';

  renderDevice =
    d:
    let
      ipMode = {
        ipv4 = 0;
        ipv6 = 1;
        dual-stack = 2;
      };
      dndMap = {
        disabled = 0;
        reject = 1;
        ringer-off = 2;
      };
      transportMap = {
        udp = 1;
        tcp = 2;
        tls = 3;
      };
      callLogBlfMap = {
        disabled = 0;
        enabled = 1;
        call-lists = 2;
        directories-and-call-lists = 3;
      };
      triMap = {
        disabled = 0;
        system = 1;
        enabled = 2;
      };
      widebandMap = {
        disabled = 0;
        enabled = 1;
        user-controlled = 2;
      };
      settingsMap = {
        disabled = 0;
        enabled = 1;
        restricted = 2;
      };
      dndAlertMap = {
        disabled = 0;
        beep = 1;
        flash = 2;
      };
      renderManager =
        index: cm:
        attrsBlock "member"
          [
            {
              name = "priority";
              value = toString index;
            }
          ]
          (
            block "callManager" (lines [
              (element "processNodeName" cm.address)
              (block "ports" (
                lines (
                  [ (element "sipPort" cm.sipPort) ]
                  ++ lib.optional (cm.securedSipPort != null) (element "securedSipPort" cm.securedSipPort)
                )
              ))
            ])
          );
      renderNtp =
        n:
        block "ntp" (lines [
          (element "name" n.name)
          (element "ntpMode" "Unicast")
        ]);
      renderAddOn =
        m:
        attrsBlock "addOnModule"
          [
            {
              name = "idx";
              value = toString m.index;
            }
          ]
          (lines [
            (element "deviceType" m.deviceType)
            (element "deviceLine" m.deviceLine)
            (element "loadInformation" m.loadInformation)
          ]);
      renderService =
        s:
        attrsBlock "phoneService"
          [
            {
              name = "type";
              value = if s.type == "application" then "1" else "2";
            }
            {
              name = "category";
              value = "0";
            }
          ]
          (lines [
            (element "name" s.name)
            (element "url" s.url)
            (element "vendor" s.vendor)
            (element "version" s.version)
          ]);
      renderSrstEndpoint =
        index: address:
        let
          suffix = toString (index + 1);
          port = if d.srst.ports == [ ] then 5060 else builtins.elemAt d.srst.ports index;
        in
        lines [
          (element "sipIpAddr${suffix}" address)
          (element "sipPort${suffix}" port)
        ];
      v = d.vendor;
      s = d.sip;
      cf = s.callFeatures;
      st = s.stack;
      url = d.urls;
    in
    ''
      <?xml version="1.0" encoding="utf-8"?>
      <device>
      ${lines [
        (boolElement "fullConfig" true)
        (element "deviceProtocol" "SIP")
        (element "ipAddressMode" ipMode.${d.ipAddressMode})
        (boolElement "allowAutoConfig" d.allowAutoConfig)
        (boolElement "dadEnable" d.duplicateAddressDetection)
        (boolElement "redirectEnable" d.acceptIcmpRedirects)
        (boolElement "echoMultiEnable" d.respondToMulticastEcho)
        (element "ipPreferenceModeControl" 0)
        (element "ipMediaAddressFamilyPreference" 0)
        (block "devicePool" (lines [
          (block "dateTimeSetting" (lines [
            (element "dateTemplate" d.dateTime.dateTemplate)
            (element "timeZone" d.dateTime.timeZone)
            (block "ntps" (lines (map renderNtp d.dateTime.ntpServers)))
          ]))
          (block "callManagerGroup" (block "members" (lines (lib.imap0 renderManager d.callManagers))))
          (optionalString d.srst.enabled (
            block "srstInfo" (lines [
              (element "srstOption" "Enable")
              (lines (lib.imap0 renderSrstEndpoint d.srst.addresses))
              (boolElement "isSecure" d.srst.secure)
            ])
          ))
          (optionalElement "connectionMonitorDuration" d.connectionMonitorDuration)
        ]))
        (block "sipProfile" (lines [
          (block "sipProxies" (boolElement "registerWithProxy" s.registerWithProxy))
          (block "sipCallFeatures" (lines [
            (boolElement "cnfJoinEnabled" cf.conferenceJoin)
            (element "callForwardURI" cf.callForwardURI)
            (element "callPickupURI" cf.callPickupURI)
            (element "callPickupListURI" cf.otherPickupURI)
            (element "callPickupGroupURI" cf.groupPickupURI)
            (element "meetMeServiceURI" cf.meetMeURI)
            (element "abbreviatedDialURI" cf.abbreviatedDialURI)
            (optionalString (cf.holdStyle != null) (
              boolElement "rfc2543Hold" (cf.holdStyle == "rfc2543")
            ))
            (optional01Element "callHoldRingback" cf.callHoldRingback)
            (optionalBoolElement "localCfwdEnable" cf.localCallForward)
            (optionalBoolElement "semiAttendedTransfer" cf.semiAttendedTransfer)
            (optional01Element "anonymousCallBlock" cf.anonymousCallBlock)
            (optional01Element "callerIdBlocking" cf.callerIdBlocking)
            (optionalString (cf.dndControl != null) (element "dndControl" dndMap.${cf.dndControl}))
            (boolElement "remoteCcEnable" cf.remoteCallControl)
            (boolElement "retainForwardInformation" cf.retainForwardInformation)
            (optionalString (cf.uriDisplay != null) (
              element "uriDialingDisplayPreference" (if cf.uriDisplay == "number-first" then 1 else 0)
            ))
          ]))
          (block "sipStack" (lines [
            (element "sipInviteRetx" st.inviteRetransmissions)
            (element "sipRetx" st.nonInviteRetransmissions)
            (element "timerInviteExpires" st.inviteExpires)
            (element "timerRegisterExpires" st.registerExpires)
            (element "timerRegisterDelta" st.registerDelta)
            (element "timerKeepAliveExpires" st.keepAliveExpires)
            (element "timerSubscribeExpires" st.subscribeExpires)
            (element "timerSubscribeDelta" st.subscribeDelta)
            (element "timerT1" st.t1)
            (element "timerT2" st.t2)
            (element "maxRedirects" st.maxRedirects)
            (boolElement "remotePartyID" st.remotePartyId)
            (element "userInfo" (if st.numericUserInfo then "Phone" else "None"))
          ]))
          (optionalElement "autoAnswerTimer" s.autoAnswerTimer)
          (optionalBoolElement "autoAnswerAltBehavior" s.autoAnswerAlternateBehavior)
          (optionalBoolElement "autoAnswerOverride" s.autoAnswerOverride)
          (optionalBoolElement "transferOnhookEnabled" s.transferOnHook)
          (optionalBoolElement "enableVad" s.voiceActivityDetection)
          (optionalElement "preferredCodec" s.preferredCodec)
          (optionalString (s.dtmf != null) (element "dtmfAvtPayload" s.dtmf.payload))
          (optionalString (s.dtmf != null) (element "dtmfDbLevel" s.dtmf.dbLevel))
          (optionalString (s.dtmf != null) (element "dtmfOutofBand" s.dtmf.transport))
          (optionalBoolElement "alwaysUsePrimeLine" s.alwaysUsePrimeLine)
          (optionalBoolElement "alwaysUsePrimeLineVoiceMail" s.alwaysUsePrimeLineForVoiceMail)
          (element "kpml" (if s.kpml then 1 else 0))
          (optionalString (s.phoneLabel != "") (element "phoneLabel" s.phoneLabel))
          (optional01Element "stutterMsgWaiting" s.stutterMessageWaiting)
          (optionalBoolElement "callStats" s.callStats)
          (optionalElement "offhookToFirstDigitTimer" s.offHookToFirstDigitTimer)
          (optionalElement "silentPeriodBetweenCallWaitingBursts" s.callWaitingBurstSilence)
          (optionalBoolElement "disableLocalSpeedDialConfig" s.disableLocalSpeedDialConfig)
          (optionalString (s.mediaPorts != null) (element "startMediaPort" s.mediaPorts.first))
          (optionalString (s.mediaPorts != null) (element "stopMediaPort" s.mediaPorts.last))
          (boolElement "natEnabled" s.nat.enabled)
          (boolElement "natReceivedProcessing" s.nat.receivedProcessing)
          (optionalElement "natAddress" s.nat.address)
          (block "sipLines" (lines (map renderButton s.buttons)))
          (optionalElement "externalNumberMask" s.externalNumberMask)
          (element "voipControlPort" s.localPort)
          (optionalElement "dscpForAudio" s.dscpForAudio)
          (optionalString (s.busyStationRingPolicy != null) (element "ringSettingBusyStationPolicy" 0))
          (optionalString (s.dialPlan != null) (element "dialTemplate" (dialPlanFilename s.dialPlan)))
          (optionalString (s.softKeys != null) (element "softKeyFile" (softKeysFilename s.softKeys)))
        ]))
        (optionalString (d.missedCallLogging != null) (
          element "MissedCallLoggingOption" (if d.missedCallLogging then 1 else 0)
        ))
        (block "commonProfile" (lines [
          (optionalString (d.commonProfile.phonePassword != "") (
            element "phonePassword" d.commonProfile.phonePassword
          ))
          (optionalString (d.wallpaperFile != null) (boolElement "backgroundImageAccess" false))
          (optionalString (d.commonProfile.callLogBlf != null) (
            element "callLogBlfEnabled" callLogBlfMap.${d.commonProfile.callLogBlf}
          ))
        ]))
        (block "vendorConfig" (lines [
          (optionalString (d.wallpaperFile != null) (
            element "defaultWallpaperFile" (wallpaperFilename d.wallpaperFile)
          ))
          (boolElement "disableSpeaker" v.disableSpeaker)
          (boolElement "disableSpeakerAndHeadset" v.disableSpeakerAndHeadset)
          (optionalString (v.pcPort != null) (element "pcPort" (if v.pcPort then 0 else 1)))
          (optionalString (v.settingsAccess != null) (element "settingsAccess" settingsMap.${v.settingsAccess}))
          (optional01Element "garp" v.gratuitousArp)
          (optional01Element "voiceVlanAccess" v.voiceVlanAccess)
          (optional01Element "spanToPCPort" v.spanToPcPort)
          (optional01Element "loggingDisplay" v.loggingDisplay)
          (optional01Element "ehookEnable" v.electronicHookswitch)
          (optional01Element "autoSelectLineEnable" v.autoSelectLine)
          (optional01Element "rtcp" v.rtcp)
          (optional01Element "dfBit" v.dontFragment)
          (element "webProtocol" (if v.webProtocol == "http-and-https" then 0 else 1))
          (element "webAccess" (if v.webAccess then 0 else 1))
          (element "sshAccess" (if v.sshAccess then 1 else 0))
          (optionalElement "loadServer" v.loadServer)
          (optional01Element "peerFirmwareSharing" v.peerFirmwareSharing)
          (optional01Element "enableCdpSwPort" v.cdpSwitchPort)
          (optional01Element "enableCdpPcPort" v.cdpPcPort)
          (optional01Element "enableLldpSwPort" v.lldpSwitchPort)
          (optional01Element "enableLldpPcPort" v.lldpPcPort)
          (optional01Element "powerNegotiation" v.powerNegotiation)
          (element "g722CodecSupport" triMap.${v.g722})
          (element "handsetWidebandEnable" widebandMap.${v.handsetWideband})
          (element "headsetWidebandEnable" widebandMap.${v.headsetWideband})
          (element "handsetWidebandUIControl" (if v.handsetWidebandUiControl then 1 else 0))
          (element "headsetWidebandUIControl" (if v.headsetWidebandUiControl then 1 else 0))
          (optionalElement "minimumRingVolume" v.minimumRingVolume)
          (optional01Element "recordingTone" v.recordingTone)
          (optionalElement "recordingToneLocalVolume" v.recordingToneLocalVolume)
          (optionalElement "recordingToneRemoteVolume" v.recordingToneRemoteVolume)
          (optionalElement "recordingToneDuration" v.recordingToneDuration)
          (optionalElement "moreKeyReversionTimer" v.moreKeyReversionTimer)
          (optionalString (v.display != null) (
            lines [
              (element "daysDisplayNotActive" (concatMapStringsSep "," toString v.display.inactiveDays))
              (element "displayOnTime" v.display.onTime)
              (element "displayOnDuration" v.display.onDuration)
              (element "displayIdleTimeout" v.display.idleTimeout)
              (element "displayOnWhenIncomingCall" (if v.display.onForIncomingCall then 1 else 0))
            ]
          ))
        ]))
        (element "versionStamp" (configHash {
          device = d;
          loadInformation = cfg.firmware.loadInformation;
        }))
        (element "loadInformation" cfg.firmware.loadInformation)
        (optionalElement "inactiveLoadInformation" d.inactiveLoadInformation)
        (optionalString (d.addOnModules != [ ]) (
          block "addOnModules" (lines (map renderAddOn d.addOnModules))
        ))
        (optionalString (d.phoneServices.services != [ ]) (
          attrsBlock "phoneServices"
            [
              {
                name = "useHTTPS";
                value = if d.phoneServices.useHTTPS then "true" else "false";
              }
            ]
            (lines [
              (element "provisioning" 2)
              (lines (map renderService d.phoneServices.services))
            ])
        ))
        (optionalString (d.userLocale != null) (
          block "userLocale" (lines [
            (element "name" d.userLocale.name)
            (element "uid" d.userLocale.uid)
            (element "langCode" d.userLocale.languageCode)
            (element "version" d.userLocale.version)
            (element "winCharSet" d.userLocale.windowsCharset)
          ])
        ))
        (optionalString (d.networkLocale != null) (
          lines [
            (element "networkLocale" d.networkLocale.name)
            (block "networkLocaleInfo" (lines [
              (element "name" d.networkLocale.name)
              (element "version" d.networkLocale.version)
            ]))
          ]
        ))
        (optionalString (d.deviceSecurityMode != null) (
          element "deviceSecurityMode" {
            non-secure = 1;
            authenticated = 2;
            encrypted = 3;
          }.${d.deviceSecurityMode}
        ))
        (optionalElement "idleTimeout" d.idleTimeout)
        (optionalElement "authenticationURL" url.authentication)
        (optionalElement "messagesURL" url.messages)
        (optionalElement "servicesURL" url.services)
        (optionalElement "directoryURL" url.directory)
        (optionalElement "idleURL" url.idle)
        (optionalElement "informationURL" url.information)
        (optionalElement "proxyServerURL" url.proxy)
        (optionalElement "secureAuthenticationURL" url.secureAuthentication)
        (optionalElement "secureMessagesURL" url.secureMessages)
        (optionalElement "secureServicesURL" url.secureServices)
        (optionalElement "secureDirectoryURL" url.secureDirectory)
        (optionalElement "secureInformationURL" url.secureInformation)
        (optionalElement "secureIdleURL" url.secureIdle)
        (element "transportLayerProtocol" transportMap.${d.transport})
        (optionalElement "TLSResumptionTimer" d.tlsResumptionTimer)
        (optionalBoolElement "phonePersonalization" d.phonePersonalization)
        (optionalBoolElement "autoCallPickupEnable" d.autoCallPickup)
        (optionalString (d.blfAudibleAlertWhenIdle != null) (
          element "blfAudibleAlertSettingOfIdleStation" (if d.blfAudibleAlertWhenIdle then 1 else 0)
        ))
        (optionalString (d.blfAudibleAlertWhenBusy != null) (
          element "blfAudibleAlertSettingOfBusyStation" (if d.blfAudibleAlertWhenBusy then 1 else 0)
        ))
        (optionalString (d.dndCallAlert != null) (element "dndCallAlert" dndAlertMap.${d.dndCallAlert}))
        (optionalElement "dndReminderTimer" d.dndReminderTimer)
        (element "advertiseG722Codec" (if d.advertiseG722 then 1 else 0))
        (optionalString (d.rollover != null) (element "rollover" (if d.rollover then 1 else 0)))
        (optional01Element "joinAcrossLines" d.joinAcrossLines)
        (optionalElement "sshUserId" d.ssh.user)
        (optionalElement "sshPassword" d.ssh.password)
      ]}
      </device>
    '';

  deviceAssertions =
    deviceName: d:
    let
      buttons = d.sip.buttons;
      physicalLimit = 8 + lib.foldl' (acc: m: acc + m.deviceLine) 0 d.addOnModules;
      lineButtons = builtins.filter (b: b.kind == "line" || b.kind == "intercom") buttons;
      unsharedLines = builtins.filter (b: b.kind == "line" && !b.sharedLine) buttons;
      specifiedContacts = builtins.filter (b: b.contact != "") buttons;
      needsNumber =
        b:
        builtins.elem b.kind [
          "speed-dial"
          "blf-speed-dial"
          "blf-directed-park"
        ];
      dialTemplates = if d.sip.dialPlan == null then [ ] else d.sip.dialPlan.templates;
      softKeyStates = if d.sip.softKeys == null then [ ] else assignedSoftKeyStates d.sip.softKeys;
      requiredSoftKeyPresent =
        state: keyID:
        let
          keys = if d.sip.softKeys == null then null else d.sip.softKeys.${state};
        in
        keys == null || builtins.elem keyID keys;
    in
    [
      {
        assertion = d.sip.mediaPorts == null || d.sip.mediaPorts.first < d.sip.mediaPorts.last;
        message = "cisco7975g ${deviceName}: first RTP port must be below last RTP port";
      }
      {
        assertion = d.sip.stack.registerDelta < d.sip.stack.registerExpires;
        message = "cisco7975g ${deviceName}: registerDelta must be below registerExpires";
      }
      {
        assertion = d.sip.stack.subscribeDelta < d.sip.stack.subscribeExpires;
        message = "cisco7975g ${deviceName}: subscribeDelta must be below subscribeExpires";
      }
      {
        assertion = !d.sip.nat.enabled || d.sip.nat.address != null;
        message = "cisco7975g ${deviceName}: sip.nat.address is required when NAT is enabled";
      }
      {
        assertion = d.vendor.sshAccess != true || (d.ssh.user != null && d.ssh.password != null);
        message = "cisco7975g ${deviceName}: SSH credentials are required when SSH access is enabled";
      }
      {
        assertion = builtins.length d.addOnModules <= 2;
        message = "cisco7975g ${deviceName}: at most two expansion modules are supported";
      }
      {
        assertion = builtins.length d.srst.addresses <= 3;
        message = "cisco7975g ${deviceName}: at most three SRST addresses are supported";
      }
      {
        assertion = !d.srst.enabled || d.srst.addresses != [ ];
        message = "cisco7975g ${deviceName}: SRST requires at least one address";
      }
      {
        assertion = d.srst.ports == [ ] || builtins.length d.srst.ports == builtins.length d.srst.addresses;
        message = "cisco7975g ${deviceName}: SRST ports must be empty or correspond one-for-one with addresses";
      }
      {
        assertion = lib.all (b: b.button <= physicalLimit) buttons;
        message = "cisco7975g ${deviceName}: a button exceeds the base-phone plus expansion-module capacity";
      }
      {
        assertion = builtins.length (lib.unique (map (b: b.button) buttons)) == builtins.length buttons;
        message = "cisco7975g ${deviceName}: physical button numbers must be unique";
      }
      {
        assertion = lib.all (b: b.lineIndex != null && b.lineIndex > 0) lineButtons;
        message = "cisco7975g ${deviceName}: line/intercom buttons require a positive lineIndex";
      }
      {
        assertion =
          builtins.length (lib.unique (map (b: b.lineIndex) lineButtons)) == builtins.length lineButtons;
        message = "cisco7975g ${deviceName}: lineIndex values must be unique";
      }
      {
        assertion = lib.all (b: b.name != "") lineButtons;
        message = "cisco7975g ${deviceName}: line/intercom buttons require a SIP name (address of record)";
      }
      {
        assertion =
          builtins.length (lib.unique (map (b: b.name) unsharedLines)) == builtins.length unsharedLines;
        message = "cisco7975g ${deviceName}: unshared line names must be unique; reuse a name only with sharedLine";
      }
      {
        assertion = lib.all (b: b.kind != "line" || b.authPassword == "" || b.authName != "") buttons;
        message = "cisco7975g ${deviceName}: authName is required when authPassword is set";
      }
      {
        assertion = lib.all (b: b.kind != "line" || b.busyTrigger <= b.maxNumCalls) buttons;
        message = "cisco7975g ${deviceName}: busyTrigger must not exceed maxNumCalls";
      }
      {
        assertion = lib.all (b: !(needsNumber b) || b.speedDialNumber != null) buttons;
        message = "cisco7975g ${deviceName}: speed-dial/BLF/park buttons require speedDialNumber";
      }
      {
        assertion =
          builtins.length (lib.unique (map (b: b.contact) specifiedContacts))
          == builtins.length specifiedContacts;
        message = "cisco7975g ${deviceName}: nonempty contact values must be unique";
      }
      {
        assertion = lib.all (
          b: b.kind != "service-url" || ((b.serviceURI != null) != (b.secureServiceURI != null))
        ) buttons;
        message = "cisco7975g ${deviceName}: a service-url button requires exactly one of serviceURI or secureServiceURI";
      }
      {
        assertion = lib.all (cm: cm.address != "") d.callManagers;
        message = "cisco7975g ${deviceName}: every call manager requires an address";
      }
      {
        assertion = lib.all (template: builtins.length template.tones <= 3) dialTemplates;
        message = "cisco7975g ${deviceName}: dial-plan templates support at most three tones";
      }
      {
        assertion = d.sip.softKeys == null || softKeyStates != [ ];
        message = "cisco7975g ${deviceName}: softKeys requires at least one call state";
      }
      {
        assertion = lib.all (state: builtins.length d.sip.softKeys.${state} <= 16) softKeyStates;
        message = "cisco7975g ${deviceName}: softkey sets support at most sixteen keys";
      }
      {
        assertion = requiredSoftKeyPresent "On Hook" "NewCall";
        message = "cisco7975g ${deviceName}: the On Hook softkey set must contain NewCall";
      }
      {
        assertion = requiredSoftKeyPresent "Digits After First" "<<";
        message = "cisco7975g ${deviceName}: the Digits After First softkey set must contain <<";
      }
    ];

in
{
  options.services.cisco = {
    enable = mkEnableOption "typed Cisco 7975G enterprise-SIP configuration generation";
    bindHost = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address on which the configuration HTTP and TFTP servers listen.";
    };
    httpPort = mkOption {
      type = types.nullOr (types.ints.between 1 65535);
      default = 6970;
      description = ''
        TCP port for the configuration HTTP server (Cisco's usual 6970).
        Set to null to disable the HTTP server.
      '';
    };
    tftpPort = mkOption {
      type = types.nullOr (types.ints.between 1 65535);
      default = 69;
      description = ''
        UDP port for the configuration TFTP server (the standard TFTP port is 69).
        Set to null to disable the TFTP server.
      '';
    };
    secretsPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/agenix/cisco";
      description = ''
        Runtime file of KEY=value secrets (for example an agenix secret).
        Placeholders `$NAME` or `''${NAME}` in generated XML are replaced at
        service start. XML-special characters in values are escaped.
        Null means no substitution; HTTP and TFTP serve the Nix store root
        directly.
      '';
    };
    firmware = mkOption {
      type = types.package;
      default = pkgs.cisco-7975g-firmware;
      defaultText = lib.literalExpression "pkgs.cisco-7975g-firmware";
      description = ''
        Firmware package to serve. Its files must be placed at the package root,
        and its `loadInformation` attribute must contain the Cisco load ID.
      '';
    };
    devices = mkOption {
      type = types.attrsOf deviceType;
      default = { };
      description = "Cisco 7975G devices keyed by an arbitrary Nix name.";
    };
    ringtones = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Custom ringtones served as Ringlist.xml. Attribute names are the
        phone menu labels (1-25 characters). Values are raw 8 kHz 8-bit
        µ-law PCM files (240-16080 bytes, size divisible by 240).
      '';
    };
    generatedConfigs = mkOption {
      type = types.attrsOf types.lines;
      readOnly = true;
      description = "Rendered phone, dial-plan, softkey, wallpaper, and ringtone XML documents keyed by their served filename.";
    };
    serverRoot = mkOption {
      type = types.nullOr types.package;
      internal = true;
      default = null;
      description = "HTTP/TFTP document root for firmware and generated phone files.";
    };
    serveBin = mkOption {
      type = types.package;
      internal = true;
      description = "Runtime HTTP/TFTP helper that optionally substitutes secrets.";
    };
  };

  config = mkIf cfg.enable {
    assertions =
      (lib.concatLists (mapAttrsToList deviceAssertions cfg.devices))
      ++ [
        {
          assertion = builtins.length (builtins.attrNames cfg.ringtones) <= 50;
          message = "cisco: at most 50 ringtones are supported";
        }
        {
          assertion = lib.all (
            name:
            let
              n = builtins.stringLength name;
            in
            n >= 1 && n <= 25
          ) (builtins.attrNames cfg.ringtones);
          message = "cisco: ringtone display names must be 1-25 characters";
        }
      ];
    services.cisco.generatedConfigs =
      let
        wallpaperFiles = lib.unique (
          builtins.filter (wallpaperFile: wallpaperFile != null) (
            mapAttrsToList (_: d: d.wallpaperFile) cfg.devices
          )
        );
        deviceConfigs = mapAttrsToList (_: d: {
          name = "SEP${d.macAddress}.cnf.xml";
          value = renderDevice d;
        }) cfg.devices;
        ringList = renderRingList cfg.ringtones;
        auxiliaryConfigs =
          lib.concatLists (
            mapAttrsToList (
              _: d:
              lib.optional (d.sip.dialPlan != null) {
                name = dialPlanFilename d.sip.dialPlan;
                value = renderDialPlan d.sip.dialPlan;
              }
              ++ lib.optional (d.sip.softKeys != null) {
                name = softKeysFilename d.sip.softKeys;
                value = renderSoftKeys d.sip.softKeys;
              }
            ) cfg.devices
          )
          ++ lib.optional (wallpaperFiles != [ ]) {
            name = "${wallpaperDirectory}/List.xml";
            value = renderWallpaperList wallpaperFiles;
          }
          ++ lib.optionals (cfg.ringtones != { }) [
            {
              name = "Ringlist.xml";
              value = ringList;
            }
            {
              name = "DistinctiveRingList.xml";
              value = ringList;
            }
          ];
      in
      lib.listToAttrs (deviceConfigs ++ auxiliaryConfigs);
  };
}
