import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import ReflectiveCard from './ReflectiveCard.jsx';
import './style.css';

function App() {
  const [theme, setTheme] = useState('dark');
  const [webcam, setWebcam] = useState(false);
  const [tilt, setTilt] = useState(true);
  const [tint, setTint] = useState('#f1b9a4');
  const [metalness, setMetalness] = useState(1);
  const [roughness, setRoughness] = useState(0.3);
  const [blur, setBlur] = useState(6);
  const [glare, setGlare] = useState(0.5);
  const [videoSrc, setVideoSrc] = useState('');
  const [cameraError, setCameraError] = useState('');
  return <main className="app">
    <header><p className="eyebrow">REACT BITS · ORIGINAL SOURCE</p><h1>Reflective Card</h1><p className="sub">原版 WebGL 反射 · 实时倾斜 · 动态环境采样</p></header>
    <section className="stage">
      <ReflectiveCard name="Momo Chen" role="Digital Companion · 你的专属伙伴" badge="VERIFIED PROFILE" status="Always here" statusColor="#f1b9a4" idLabel="PROFILE ID" idValue="MOMO · 2026" theme={theme} tint={tint} metalness={metalness} roughness={roughness} blurStrength={blur} glare={glare} enableTilt={tilt} tiltStrength={14} webcam={webcam} onWebcamError={e => setCameraError(String(e?.message || e))} videoSrc={videoSrc || undefined} width={340} height={500} radius={28}>
        <div className="profile-content"><div className="cover-art"><div className="orbit orbit-a"/><div className="orbit orbit-b"/><div className="sun"/><span className="cover-caption">A LITTLE UNIVERSE OF OUR OWN</span></div><div className="identity"><div className="avatar">平</div><div><h2>张平</h2><p>今天也想和你一起度过。</p></div><span className="online-dot"/></div><div className="moments"><span>OUR MOMENTS</span><div className="moment-grid"><i>☁️</i><i>🌷</i><i>🌙</i></div></div><div className="actions"><button onClick={() => alert('Voice call')}>☎ 语音</button><button onClick={() => alert('Message')}>♡ 聊天</button></div></div>
      </ReflectiveCard>
    </section>
    <section className="controls"><div className="control-row"><label>Appearance</label><div className="seg"><button className={theme==='dark'?'active':''} onClick={()=>setTheme('dark')}>Dark</button><button className={theme==='light'?'active':''} onClick={()=>setTheme('light')}>Light</button></div></div>
      <div className="control-row"><label>Reflection tint</label><input type="color" value={tint} onChange={e=>setTint(e.target.value)}/><code>{tint}</code></div>
      <label className="range">Metalness <output>{metalness.toFixed(2)}</output><input type="range" min="0" max="1" step="0.05" value={metalness} onChange={e=>setMetalness(+e.target.value)}/></label>
      <label className="range">Roughness <output>{roughness.toFixed(2)}</output><input type="range" min="0" max="1" step="0.05" value={roughness} onChange={e=>setRoughness(+e.target.value)}/></label>
      <label className="range">Environment blur <output>{blur}</output><input type="range" min="0" max="20" step="1" value={blur} onChange={e=>setBlur(+e.target.value)}/></label>
      <label className="range">Glare <output>{glare.toFixed(2)}</output><input type="range" min="0" max="1" step="0.05" value={glare} onChange={e=>setGlare(+e.target.value)}/></label>
      <div className="control-row"><label>3D tilt</label><input type="checkbox" checked={tilt} onChange={e=>setTilt(e.target.checked)}/></div>
      <div className="control-row"><label>Use camera as reflection source</label><input type="checkbox" checked={webcam} onChange={e=>setWebcam(e.target.checked)}/></div>
      {cameraError && <p className="error">Camera: {cameraError}</p>}
      <label className="upload">Use a video as reflection source <input type="file" accept="video/*" onChange={e=>{const f=e.target.files?.[0]; if(f) setVideoSrc(URL.createObjectURL(f));}}/></label>
    </section><footer>此页面直接使用 React Bits 原始 ReflectiveCard.jsx + CSS，未重写其 WebGL 渲染器。</footer>
  </main>;
}

createRoot(document.getElementById('root')).render(<App />);
