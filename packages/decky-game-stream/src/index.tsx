import { callable, definePlugin, toaster } from "@decky/api";
import {
  PanelSection,
  PanelSectionRow,
  SliderField,
  ToggleField,
  findClassModule,
  findModuleExport,
  findSP,
  getGamepadNavigationTrees,
  staticClasses,
} from "@decky/ui";
import { useEffect, useRef, useState } from "react";

type Resolution = "1920x1080" | "2560x1440" | "3840x2160";
type Framerate = 30 | 60 | 120;
interface State {
  streaming: boolean;
  resolution: Resolution;
  fps: Framerate;
}
type Settings = Pick<State, "resolution" | "fps">;

const getState = callable<[], State>("get_state");
const setStreaming = callable<[enabled: boolean], State>("set_streaming");
const setSettings = callable<[resolution: Resolution, fps: Framerate], State>("set_settings");

// slider notches, low to high
interface Notch<T> {
  value: T;
  label: string;
}
const RESOLUTIONS: Notch<Resolution>[] = [
  { value: "1920x1080", label: "1080p" },
  { value: "2560x1440", label: "1440p" },
  { value: "3840x2160", label: "4K" },
];
const FRAMERATES: Notch<Framerate>[] = ([30, 60, 120] as const).map((f) => ({ value: f, label: `${f} FPS` }));

// shared state, polled in the background so the LIVE badge works without opening the panel
let state: State = { streaming: false, resolution: "3840x2160", fps: 60 };
const listeners = new Set<(state: State) => void>();
function update(next: State) {
  state = next;
  syncBadge();
  listeners.forEach((fn) => fn(state));
}
function refresh() {
  return getState()
    .then(update)
    .catch(() => {});
}

// LIVE badge in the Steam header, left of the header icons. The header exists in several Steam windows
// (the full Steam-button bar, and the right-hand part shown with the Quick Access menu in game), so
// every window with a gamepad nav tree gets checked.
const BADGE_CLASS = "game-stream-live-badge";

interface NavTree {
  m_Root?: { m_element?: Element };
  Root?: { Element?: Element };
}

function steamDocuments() {
  const docs = new Set<Document>();
  const sp = findSP();
  if (sp) docs.add(sp.document);
  for (const tree of (getGamepadNavigationTrees() ?? []) as NavTree[]) {
    const doc = (tree?.m_Root?.m_element ?? tree?.Root?.Element)?.ownerDocument;
    if (doc) docs.add(doc);
  }
  return docs;
}

function createBadge(doc: Document) {
  const badge = doc.createElement("div");
  badge.className = BADGE_CLASS;
  badge.textContent = "LIVE";
  Object.assign(badge.style, {
    alignSelf: "center",
    flexShrink: "0",
    margin: "0 8px",
    padding: "0 8px",
    borderRadius: "4px",
    background: "#e02424",
    color: "#fff",
    fontSize: "14px",
    fontWeight: "800",
    letterSpacing: "0.08em",
    lineHeight: "22px",
  });
  return badge;
}

function syncBadge() {
  const headerClasses = findClassModule((m) => m.Header && m.Clock && m.HeaderItem) as
    | Record<string, string>
    | undefined;
  for (const doc of steamDocuments()) {
    const headers = headerClasses ? [...doc.querySelectorAll("." + headerClasses.Header)] : [];
    for (const badge of doc.querySelectorAll("." + BADGE_CLASS)) {
      if (!state.streaming || !headers.includes(badge.parentElement!)) badge.remove();
    }
    if (!state.streaming || !headerClasses) continue;
    for (const header of headers) {
      if ([...header.children].some((c) => c.classList.contains(BADGE_CLASS))) continue;
      const firstItem = [...header.children].find((c) => c.classList.contains(headerClasses.HeaderItem));
      header.insertBefore(createBadge(doc), firstItem ?? header.firstElementChild);
    }
  }
}

// Steam's "Screen Reader Enable" controller action (… + View, and Steam + View) as the stream toggle. Steam runs
// that action natively, so the plugin can't see the chord itself, only the screen reader setting flipping on.
// The action only ever enables, so the setting is reset right away to re-arm the trigger for the next press.
const SCREEN_READER = "accessibility_screen_reader_enabled";
interface ClientSettingsStore {
  clientSettings: Record<string, unknown>;
  GetClientSetting: unknown;
}
// found by shape rather than by Steam's minified export names, which change between updates; looked up lazily
// (and retried) in case Steam's modules aren't all loaded when the plugin starts
let clientSettingsStore: ClientSettingsStore | undefined;
let setClientSetting: ((name: string, value: unknown) => Promise<unknown>) | undefined;
let lastLookup = 0;
function findClientSettings() {
  // scanning Steam's modules isn't free; if a Steam update ever breaks the lookup, don't redo it every tick
  if (Date.now() - lastLookup < 5000) return;
  lastLookup = Date.now();
  clientSettingsStore ??= findModuleExport(
    (e) => e && typeof e === "object" && "clientSettings" in e && typeof e.GetClientSetting === "function",
  );
  setClientSetting ??= findModuleExport(
    (e) => typeof e === "function" && e.toString().includes("SteamClient.Settings.SetSetting"),
  );
}

const CHORD_COOLDOWN_MS = 1500;
const TOAST_MS = 2000;
let lastChord = 0;

function watchChord() {
  if (!clientSettingsStore || !setClientSetting) findClientSettings();
  if (clientSettingsStore?.clientSettings[SCREEN_READER] !== true || !setClientSetting) return;
  setClientSetting(SCREEN_READER, false);
  const now = Date.now();
  if (now - lastChord < CHORD_COOLDOWN_MS) return;
  lastChord = now;
  toggleFromChord();
}

async function toggleFromChord() {
  const wanted = !state.streaming;
  const next = await setStreaming(wanted);
  update(next);
  const resolution = RESOLUTIONS.find((r) => r.value === next.resolution)?.label ?? next.resolution;
  // Steam's popup toast: title is the small header next to the icon, body the main line
  const message =
    next.streaming !== wanted ? "Stream toggle failed" : wanted ? `Stream started · ${resolution} · ${next.fps} FPS` : "Stream stopped";
  // short, and gone from the Notifications list once shown (expiration removes it from the tray)
  toaster.toast({ title: "Game Stream", body: message, icon: <Icon />, duration: TOAST_MS, expiration: TOAST_MS });
}

function Icon() {
  return (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="currentColor">
      <path d="M12 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm-4.24-1.76-1.42-1.42a7.5 7.5 0 0 0 0 10.36l1.42-1.42a5.5 5.5 0 0 1 0-7.52zm8.48 0a5.5 5.5 0 0 1 0 7.52l1.42 1.42a7.5 7.5 0 0 0 0-10.36l-1.42 1.42zM4.93 5.4 3.51 4a10.5 10.5 0 0 0 0 16l1.42-1.4a8.5 8.5 0 0 1 0-13.2zm14.14 0a8.5 8.5 0 0 1 0 13.2L20.49 20a10.5 10.5 0 0 0 0-16l-1.42 1.4z" />
    </svg>
  );
}

interface NotchSliderProps<T> {
  label: string;
  notches: Notch<T>[];
  value: T;
  bottomSeparator?: "standard" | "thick" | "none";
  onChange: (value: T) => void;
}

function NotchSlider<T>({ label, notches, value, bottomSeparator, onChange }: NotchSliderProps<T>) {
  const index = Math.max(
    0,
    notches.findIndex((n) => n.value === value),
  );
  return (
    <SliderField
      label={label}
      value={index}
      min={0}
      max={notches.length - 1}
      step={1}
      notchCount={notches.length}
      notchLabels={notches.map((n, i) => ({ notchIndex: i, label: n.label, value: i }))}
      notchTicksVisible={false}
      showValue={false}
      bottomSeparator={bottomSeparator}
      onChange={(i) => onChange(notches[i].value)}
    />
  );
}

function Content() {
  const [current, setCurrent] = useState(state);
  const [busy, setBusy] = useState(false);
  const settingsTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  // settings picked on the sliders but not applied yet, kept over background refreshes
  const pending = useRef<Settings | null>(null);

  useEffect(() => {
    const listener = (next: State) => setCurrent({ ...next, ...pending.current });
    listeners.add(listener);
    refresh();
    return () => {
      listeners.delete(listener);
      clearTimeout(settingsTimer.current);
    };
  }, []);

  const toggle = async (enabled: boolean) => {
    setBusy(true);
    setCurrent({ ...state, ...pending.current, streaming: enabled });
    try {
      update(await setStreaming(enabled));
    } finally {
      setBusy(false);
    }
  };

  // sliders move through intermediate notches, only apply (and restart capture) once they settle
  const changeSettings = (patch: Partial<Settings>) => {
    const next: Settings = { resolution: state.resolution, fps: state.fps, ...pending.current, ...patch };
    pending.current = next;
    setCurrent({ ...state, ...next });
    clearTimeout(settingsTimer.current);
    settingsTimer.current = setTimeout(() => {
      setSettings(next.resolution, next.fps).then((applied) => {
        pending.current = null;
        update(applied);
      });
    }, 600);
  };

  return (
    <PanelSection>
      <PanelSectionRow>
        <ToggleField
          label="Streaming"
          description={current.streaming ? "Live" : "Off"}
          checked={current.streaming}
          disabled={busy}
          onChange={toggle}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <NotchSlider
          label="Resolution"
          notches={RESOLUTIONS}
          value={current.resolution}
          onChange={(resolution) => changeSettings({ resolution })}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <NotchSlider
          label="Maximum framerate"
          notches={FRAMERATES}
          value={current.fps}
          bottomSeparator="none"
          onChange={(fps) => changeSettings({ fps })}
        />
      </PanelSectionRow>
    </PanelSection>
  );
}

export default definePlugin(() => {
  refresh();
  const timer = setInterval(refresh, 2000);
  // quick, so the badge is there as soon as a header (re)appears, e.g. when opening Quick Access
  const badgeTimer = setInterval(() => {
    try {
      syncBadge();
    } catch (e) {
      console.error("game-stream: badge", e);
    }
  }, 500);
  // a cheap boolean read, so polling it often keeps the chord responsive
  const chordTimer = setInterval(watchChord, 150);

  return {
    name: "Game Stream",
    titleView: <div className={staticClasses.Title}>Game Stream</div>,
    content: <Content />,
    icon: <Icon />,
    onDismount() {
      clearInterval(timer);
      clearInterval(badgeTimer);
      clearInterval(chordTimer);
      state = { ...state, streaming: false };
      syncBadge();
    },
  };
});
