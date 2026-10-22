package com.charlesproxy.gui.menus;

import com.charlesproxy.CharlesContext;
import com.charlesproxy.EKMc;
import com.charlesproxy.Strings_;
import com.charlesproxy.config.rZRx;
import com.charlesproxy.gui.CharlesFrame;
import com.charlesproxy.gui.tools.CharlesGUITool;
import com.charlesproxy.gui.tools.ToolCheckBoxMenuItem;
import com.charlesproxy.gui.tools.breakpoints.IBreakpointsTool;
import com.charlesproxy.hqtm.rkLW;
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

        JMenuItem startRecording = new JMenuItem(rkLW.yPDK(Strings_.YCFk));
        startRecording.setEnabled(false);
        startRecording.setMnemonic('r');
        startRecording.setAccelerator(
                KeyStroke.getKeyStroke(82, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        startRecording.addActionListener(
                (java.awt.event.ActionListener)
                        make("Innl", new Class[] {ProxyMenu.class, CharlesFrame.class}, this, charlesFrame));
        charlesFrame.addPropertyChangeListener(
                (java.beans.PropertyChangeListener)
                        make("kbXb", new Class[] {ProxyMenu.class, JMenuItem.class}, this, startRecording));
        CharlesContext.getInstance()
                .getProxyManager()
                .yPDK(
                        (java.beans.PropertyChangeListener)
                                make(
                                        "fgXo",
                                new Class[] {ProxyMenu.class, JMenuItem.class, CharlesFrame.class},
                                this,
                                        startRecording,
                                        charlesFrame));
        this.add(startRecording);

        rZRx sslConfiguration = context.getConfiguration().yPDK();
        JMenuItem sslProxying =
                new JMenuItem(
                        sslConfiguration.ZJTz()
                                ? rkLW.yPDK(Strings_.UiMh)
                                : rkLW.yPDK(Strings_.LHST));
        sslProxying.setMnemonic('p');
        sslProxying.setAccelerator(
                KeyStroke.getKeyStroke(76, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        sslProxying.addActionListener(
                (java.awt.event.ActionListener)
                        make(
                                "IoGp",
                                new Class[] {ProxyMenu.class, rZRx.class, CharlesContext.class},
                                this,
                                sslConfiguration,
                                context));
        sslConfiguration.addPropertyChangeListener(
                "decryptSSL",
                (java.beans.PropertyChangeListener)
                        make("CPHi", new Class[] {ProxyMenu.class, JMenuItem.class}, this, sslProxying));
        this.add(sslProxying);

        JMenuItem throttling = new JMenuItem(rkLW.yPDK(Strings_.xfuh));
        throttling.setMnemonic('t');
        throttling.setAccelerator(
                KeyStroke.getKeyStroke(84, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        throttling.addActionListener(
                (java.awt.event.ActionListener)
                        make("dEuo", new Class[] {ProxyMenu.class, CharlesContext.class}, this, context));
        context.getProxyManager()
                .yPDK(
                        "throttling",
                        (java.beans.PropertyChangeListener)
                                make("eZEl", new Class[] {ProxyMenu.class, JMenuItem.class}, this, throttling));
        this.add(throttling);

        IBreakpointsTool breakpointsTool = context.getTool(IBreakpointsTool.class);
        boolean breakpointsActive = breakpointsTool.isActive();
        JMenuItem breakpoints =
                new JMenuItem(
                        breakpointsActive ? rkLW.yPDK(Strings_.Xfzf) : rkLW.yPDK(Strings_.zVZS));
        breakpoints.setAccelerator(
                KeyStroke.getKeyStroke(75, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx()));
        breakpoints.addActionListener(
                (java.awt.event.ActionListener)
                        make(
                                "JovI",
                                new Class[] {ProxyMenu.class, IBreakpointsTool.class},
                                this,
                                breakpointsTool));
        breakpointsTool.addToolListener(
                (com.charlesproxy.tools.spi.lib.ToolListener)
                        make("eJVD", new Class[] {ProxyMenu.class, JMenuItem.class}, this, breakpoints));
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
                                Strings_.kZCR,
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
        if (EKMc.yPDK()) {
            EKMc macOSProxy = EKMc.Oezn();
            if (macOSProxy != null) {
                JCheckBoxMenuItem macOSProxyItem = new JCheckBoxMenuItem(macOSProxy.ScVR());
                macOSProxyItem.setSelected(macOSProxy.xGrV());
                macOSProxyItem.setMnemonic(macOSProxy.jwHf());
                macOSProxyItem.setAccelerator(
                        KeyStroke.getKeyStroke(
                                80, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx() | 0x40));
                macOSProxyItem.addItemListener(
                        (ItemListener)
                                make("wCRv", new Class[] {ProxyMenu.class, EKMc.class}, this, macOSProxy));
                macOSProxy.yPDK(
                        (java.beans.PropertyChangeListener)
                                make(
                                        "gCbV",
                                        new Class[] {ProxyMenu.class, JCheckBoxMenuItem.class},
                                        this,
                                        macOSProxyItem));
                this.add(macOSProxyItem);
            }
            addedPlatformToggle = true;
        }
        if (com.charlesproxy.eTnZ.rkLW.ScVR()) {
            JCheckBoxMenuItem windowsProxyItem = new JCheckBoxMenuItem(rkLW.yPDK(Strings_.WieX));
            windowsProxyItem.setSelected(com.charlesproxy.eTnZ.rkLW.xGrV());
            windowsProxyItem.setMnemonic('f');
            windowsProxyItem.setAccelerator(
                    KeyStroke.getKeyStroke(
                            70, Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx() | 0x40));
            ItemListener windowsProxyListener =
                    (ItemListener) make("DqeP", new Class[] {ProxyMenu.class}, this);
            windowsProxyItem.addItemListener(windowsProxyListener);
            com.charlesproxy.eTnZ.rkLW.yPDK(
                    (java.beans.PropertyChangeListener)
                            make(
                                    "ajWk",
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

    public static void yPDK() {
        CharlesContext.getInstance()
                .error(
                        "One or more of the required proxy servers are not currently active. "
                                + "Please check the Proxy Settings.");
    }
}
