{ lib }:
let
  bands = [
    {
      freq = 101.0;
      type = 5;
      gain = 0.1244514611771385;
      q = 4.36;
    }
    {
      freq = 451.0;
      type = 1;
      gain = 0.5321082592667942;
      q = 2.46;
    }
    {
      freq = 918.0;
      type = 1;
      gain = 0.5780960474057181;
      q = 2.44;
    }
    {
      freq = 9700.0;
      type = 1;
      gain = 2.5409727055493048;
      q = 2.0;
    }
  ];
  eqControls = lib.foldl' (acc: attrs: acc // attrs) { } (
    lib.concatMap
      (
        side:
        lib.imap0 (i: band: {
          "f${side}_${toString i}" = band.freq;
          "fm${side}_${toString i}" = 0;
          "ft${side}_${toString i}" = band.type;
          "g${side}_${toString i}" = band.gain;
          "hue${side}_${toString i}" = i * 3.125e-2;
          "q${side}_${toString i}" = band.q;
          "s${side}_${toString i}" = 0;
          "w${side}_${toString i}" = 4.0;
        }) bands
      )
      [
        "l"
        "r"
      ]
  );
  chain = [
    "bassex"
    "el"
    "fw13eq"
    "woofer_bp"
    "woofer_lim"
  ];
in
{
  nodes = [
    {
      type = "lv2";
      plugin = "https://chadmed.au/bankstown";
      name = "bassex";
      control = {
        bypass = 0;
        amt = 1.2;
        sat_second = 1.3;
        sat_third = 2.5;
        blend = 1.0;
        ceil = 200.0;
        floor = 20.0;
      };
    }
    {
      type = "lv2";
      plugin = "http://lsp-plug.in/plugins/lv2/loud_comp_stereo";
      name = "el";
      control = {
        enabled = 1;
        input = 1.0;
        fft = 4;
      };
    }
    {
      type = "lv2";
      plugin = "http://lsp-plug.in/plugins/lv2/para_equalizer_x8_lr";
      name = "fw13eq";
      control = eqControls // {
        mode = 0;
        react = 0.2;
        zoom = 1.5848931924611134e-2;
      };
    }
    {
      type = "lv2";
      plugin = "http://lsp-plug.in/plugins/lv2/mb_compressor_stereo";
      name = "woofer_bp";
      control = {
        mode = 0;
        ce_0 = 1;
        sla_0 = 5.0;
        cr_0 = 1.75;
        al_0 = 0.725;
        at_0 = 1.0;
        rt_0 = 100;
        kn_0 = 0.125;
        cbe_1 = 1;
        sf_1 = 200.0;
        ce_1 = 0;
        cbe_2 = 0;
        ce_2 = 0;
        cbe_3 = 0;
        ce_3 = 0;
        cbe_4 = 0;
        ce_4 = 0;
        cbe_5 = 0;
        ce_5 = 0;
        cbe_6 = 0;
        ce_6 = 0;
      };
    }
    {
      type = "lv2";
      plugin = "http://lsp-plug.in/plugins/lv2/compressor_stereo";
      name = "woofer_lim";
      control = {
        sla = 5.0;
        al = 1.0;
        at = 1.0;
        rt = 100.0;
        cr = 15.0;
        kn = 0.5;
      };
    }
  ];
  links = lib.concatLists (
    lib.imap0 (
      i: name:
      map
        (side: {
          output = "${name}:out_${side}";
          input = "${builtins.elemAt chain (i + 1)}:in_${side}";
        })
        [
          "l"
          "r"
        ]
    ) (lib.init chain)
  );
  inputs = [
    "bassex:in_l"
    "bassex:in_r"
  ];
  outputs = [
    "woofer_lim:out_l"
    "woofer_lim:out_r"
  ];
  "capture.volumes" = [
    {
      control = "el:volume";
      min = -47.5;
      max = 0.0;
      scale = "cubic";
    }
  ];
}
