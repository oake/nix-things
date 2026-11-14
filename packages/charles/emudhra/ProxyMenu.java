package com.charlesproxy.gui.menus;

import com.charlesproxy.CharlesContext;
import com.charlesproxy.fYsX;
import com.charlesproxy.Strings_;
import com.charlesproxy.config.hLjh;
import com.charlesproxy.gui.CharlesFrame;
import com.charlesproxy.gui.tools.CharlesGUITool;
import com.charlesproxy.gui.tools.ToolCheckBoxMenuItem;
import com.charlesproxy.gui.tools.breakpoints.IBreakpointsTool;
import com.charlesproxy.kDMS.WgsK;
import com.charlesproxy.ssl.EmudhraMode;
import com.charlesproxy.tools.spi.lib.CharlesTool;
import java.awt.Toolkit;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.lang.reflect.Constructor;
import javax.swing.AbstractButton;
import javax.swing.ButtonGroup;
import javax.swing.ButtonModel;
import javax.swing.JRadioButtonMenuItem;
import javax.swing.JCheckBoxMenuItem;
import javax.swing.JMenu;
import javax.swing.JMenuItem;
import javax.swing.KeyStroke;

public class ProxyMenu extends JMenu {
    private static Object make(String simpleName, Class<?>[] types, Object... args) {
        try {
            Class<?> cls = Class.forName("com.charlesproxy.gui.menus." + simpleName);
            Constructor<?> ctor = cls.getDeclaredConstructor(types);
            ctor.setAccessible(true);
            return ctor.newInstance(args);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException("Failed to construct " + simpleName, e);
        }
    }

    public ProxyMenu(String title, CharlesFrame charlesFrame) {
        super(title);
        CharlesContext context = CharlesContext.getInstance();

        JMenuItem startRecording = new JMenuItem(WgsK.VJmN(Strings_.WmfX));
        startRecording.setEnabled(false);
        startRecording.setMnemonic('r');
        startRecording.setAccelerator(
                KeyStroke.getKeyStroke(82, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        startRecording.addActionListener(
                (java.awt.event.ActionListener)
                        make("DPiU", new Class[] {ProxyMenu.class, CharlesFrame.class}, this, charlesFrame));
        charlesFrame.addPropertyChangeListener(
                (java.beans.PropertyChangeListener)
                        make("MvgE", new Class[] {ProxyMenu.class, JMenuItem.class}, this, startRecording));
        CharlesContext.getInstance()
                .getProxyManager()
                .VJmN(
                        (java.beans.PropertyChangeListener)
                                make(
                                        "tRNk",
                                new Class[] {ProxyMenu.class, JMenuItem.class, CharlesFrame.class},
                                this,
                                        startRecording,
                                        charlesFrame));
        this.add(startRecording);

        hLjh sslConfiguration = context.getConfiguration().VJmN();
        JMenuItem sslProxying =
                new JMenuItem(
                        sslConfiguration.opEU()
                                ? WgsK.VJmN(Strings_.fPWg)
                                : WgsK.VJmN(Strings_.IEtj));
        sslProxying.setMnemonic('p');
        sslProxying.setAccelerator(
                KeyStroke.getKeyStroke(76, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        sslProxying.addActionListener(
                (java.awt.event.ActionListener)
                        make(
                                "UJmp",
                                new Class[] {ProxyMenu.class, hLjh.class, CharlesContext.class},
                                this,
                                sslConfiguration,
                                context));
        sslConfiguration.addPropertyChangeListener(
                "decryptSSL",
                (java.beans.PropertyChangeListener)
                        make("NOcX", new Class[] {ProxyMenu.class, JMenuItem.class}, this, sslProxying));
        this.add(sslProxying);

        JMenuItem throttling = new JMenuItem(WgsK.VJmN(Strings_.vvYm));
        throttling.setMnemonic('t');
        throttling.setAccelerator(
                KeyStroke.getKeyStroke(84, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        throttling.addActionListener(
                (java.awt.event.ActionListener)
                        make("ScOr", new Class[] {ProxyMenu.class, CharlesContext.class}, this, context));
        context.getProxyManager()
                .VJmN(
                        "throttling",
                        (java.beans.PropertyChangeListener)
                                make("HLAk", new Class[] {ProxyMenu.class, JMenuItem.class}, this, throttling));
        this.add(throttling);

        IBreakpointsTool breakpointsTool = context.getTool(IBreakpointsTool.class);
        boolean breakpointsActive = breakpointsTool.isActive();
        JMenuItem breakpoints =
                new JMenuItem(
                        breakpointsActive ? WgsK.VJmN(Strings_.IBAe) : WgsK.VJmN(Strings_.eivN));
        breakpoints.setAccelerator(
                KeyStroke.getKeyStroke(75, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        breakpoints.addActionListener(
                (java.awt.event.ActionListener)
                        make(
                                "Xido",
                                new Class[] {ProxyMenu.class, IBreakpointsTool.class},
                                this,
                                breakpointsTool));
        breakpointsTool.addToolListener(
                (com.charlesproxy.tools.spi.lib.ToolListener)
                        make("ftAB", new Class[] {ProxyMenu.class, JMenuItem.class}, this, breakpoints));
        this.add(breakpoints);

        this.addSeparator();
        this.add(charlesFrame.recordingSettingsAction);
        this.add(charlesFrame.sslSettingsAction)
                .setAccelerator(
                        KeyStroke.getKeyStroke(
                                76, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx() | 0x40));
        javax.swing.Action throttleSettingsAction =
                (javax.swing.Action)
                        make(
                                "ProxyMenu$8",
                                new Class[] {ProxyMenu.class, Strings_.class, CharlesFrame.class},
                                this,
                                Strings_.XmCH,
                                charlesFrame);
        this.add(throttleSettingsAction)
                .setAccelerator(
                        KeyStroke.getKeyStroke(
                                84, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx() | 0x40));

        for (CharlesTool charlesTool : context.getProxyTools()) {
            if (charlesTool == null) {
                this.addSeparator();
                continue;
            }
            if (charlesTool instanceof IBreakpointsTool) {
                JMenuItem toolItem = new JMenuItem(((IBreakpointsTool) charlesTool).getAction());
                toolItem.setAccelerator(((IBreakpointsTool) charlesTool).getAccelerator());
                this.add(toolItem);
                this.addSeparator();
                continue;
            }
            if (!(charlesTool instanceof CharlesGUITool)) continue;
            this.add(new ToolCheckBoxMenuItem((CharlesGUITool) charlesTool, true));
        }
        this.addSeparator();
        boolean addedPlatformToggle = false;
        if (fYsX.VJmN()) {
            fYsX macOSProxy = fYsX.OPvq();
            if (macOSProxy != null) {
                JCheckBoxMenuItem macOSProxyItem = new JCheckBoxMenuItem(macOSProxy.Vpnb());
                macOSProxyItem.setSelected(macOSProxy.yUjn());
                macOSProxyItem.setMnemonic(macOSProxy.sKdH());
                macOSProxyItem.setAccelerator(
                        KeyStroke.getKeyStroke(
                                80, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx() | 0x40));
                macOSProxyItem.addItemListener(
                        (ItemListener)
                                make("tHBK", new Class[] {ProxyMenu.class, fYsX.class}, this, macOSProxy));
                macOSProxy.VJmN(
                        (java.beans.PropertyChangeListener)
                                make(
                                        "YSpb",
                                        new Class[] {ProxyMenu.class, JCheckBoxMenuItem.class},
                                        this,
                                        macOSProxyItem));
                this.add(macOSProxyItem);
            }
            addedPlatformToggle = true;
        }
        if (com.charlesproxy.bCjs.WgsK.Vpnb()) {
            JCheckBoxMenuItem windowsProxyItem = new JCheckBoxMenuItem(WgsK.VJmN(Strings_.pbly));
            windowsProxyItem.setSelected(com.charlesproxy.bCjs.WgsK.yUjn());
            windowsProxyItem.setMnemonic('f');
            windowsProxyItem.setAccelerator(
                    KeyStroke.getKeyStroke(
                            70, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx() | 0x40));
            ItemListener windowsProxyListener =
                    (ItemListener) make("zOsZ", new Class[] {ProxyMenu.class}, this);
            windowsProxyItem.addItemListener(windowsProxyListener);
            com.charlesproxy.bCjs.WgsK.VJmN(
                    (java.beans.PropertyChangeListener)
                            make(
                                    "zTUo",
                                    new Class[] {ProxyMenu.class, JCheckBoxMenuItem.class, ItemListener.class},
                                    this,
                                    windowsProxyItem,
                                    windowsProxyListener));
            this.add(windowsProxyItem);
            addedPlatformToggle = true;
        }
        if (addedPlatformToggle) {
            this.addSeparator();
        }
        this.add(charlesFrame.proxySettingsAction);
        this.add(charlesFrame.dnsSettingsAction);
        this.add(charlesFrame.accessControlSettingsAction);
        JCheckBoxMenuItem externalProxyItem =
                new JCheckBoxMenuItem(charlesFrame.externalProxySettingsAction);
        externalProxyItem.setModel(
                (ButtonModel)
                        make(
                                "ProxyMenu$2",
                                new Class[] {ProxyMenu.class, CharlesContext.class},
                                this,
                                context));
        this.add(externalProxyItem);
        JCheckBoxMenuItem externalDnsItem =
                new JCheckBoxMenuItem(charlesFrame.externalDnsResolverSettingsAction);
        externalDnsItem.setModel(
                (ButtonModel)
                        make(
                                "ProxyMenu$3",
                                new Class[] {ProxyMenu.class, CharlesContext.class},
                                this,
                                context));
        this.add(externalDnsItem);
        JCheckBoxMenuItem remoteControlItem =
                new JCheckBoxMenuItem(charlesFrame.remoteControlSettingsAction);
        remoteControlItem.setModel(
                (ButtonModel)
                        make(
                                "ProxyMenu$1",
                                new Class[] {ProxyMenu.class, CharlesContext.class},
                                this,
                                context));
        this.add(remoteControlItem);

        // Signing CA selection (eMudhra Mode, like mitmproxy's --emudhra option).
        this.addSeparator();
        ButtonGroup caGroup = new ButtonGroup();
        JRadioButtonMenuItem charlesCAItem = new JRadioButtonMenuItem("Charles CA");
        JRadioButtonMenuItem comodoItem = new JRadioButtonMenuItem("eMudhra - Comodo AAA");
        JRadioButtonMenuItem emsignItem = new JRadioButtonMenuItem("eMudhra - emSign");
        caGroup.add(charlesCAItem);
        caGroup.add(comodoItem);
        caGroup.add(emsignItem);
        int preferredMode = EmudhraMode.getPreferredMode();
        charlesCAItem.setSelected(preferredMode == EmudhraMode.MODE_CHARLES);
        comodoItem.setSelected(preferredMode == EmudhraMode.MODE_COMODO);
        emsignItem.setSelected(preferredMode == EmudhraMode.MODE_EMSIGN);
        EmudhraMode.setMode(preferredMode);
        ItemListener caListener =
                new CaItemListener(charlesCAItem, comodoItem, emsignItem);
        charlesCAItem.addItemListener(caListener);
        comodoItem.addItemListener(caListener);
        emsignItem.addItemListener(caListener);
        this.add(charlesCAItem);
        this.add(comodoItem);
        this.add(emsignItem);
    }

    private static final class CaItemListener implements ItemListener {
        private final JMenuItem charlesCAItem;
        private final JMenuItem comodoItem;
        private final JMenuItem emsignItem;

        CaItemListener(JMenuItem charlesCAItem, JMenuItem comodoItem, JMenuItem emsignItem) {
            this.charlesCAItem = charlesCAItem;
            this.comodoItem = comodoItem;
            this.emsignItem = emsignItem;
        }

        @Override
        public void itemStateChanged(ItemEvent e) {
            if (e.getStateChange() != ItemEvent.SELECTED) {
                return;
            }
            Object source = e.getSource();
            if (source == comodoItem) {
                EmudhraMode.setMode(EmudhraMode.MODE_COMODO);
            } else if (source == emsignItem) {
                EmudhraMode.setMode(EmudhraMode.MODE_EMSIGN);
            } else {
                EmudhraMode.setMode(EmudhraMode.MODE_CHARLES);
            }
        }
    }

    public static void VJmN() {
        CharlesContext.getInstance()
                .error(
                        "One or more of the required proxy servers are not currently active. "
                                + "Please check the Proxy Settings.");
    }
}
