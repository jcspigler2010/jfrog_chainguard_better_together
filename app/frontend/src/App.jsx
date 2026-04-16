import React, { useEffect, useState } from 'react';

const API = ''; // same-origin via NGINX proxy

function useImages() {
  const [images, setImages] = useState([]);
  const [stats, setStats] = useState({});
  const refresh = async () => {
    const [i, s] = await Promise.all([
      fetch(`${API}/api/images`).then(r => r.json()),
      fetch(`${API}/api/stats`).then(r => r.json()),
    ]);
    setImages(i);
    setStats(s);
  };
  useEffect(() => { refresh(); }, []);
  return { images, stats, refresh };
}

function StatCard({ flavor, data }) {
  const empty = { image_count: 0, cves_high: 0, cves_medium: 0, cves_low: 0 };
  const d = data || empty;
  return (
    <div className={`card flavor-${flavor}`}>
      <h3>{flavor}</h3>
      <div className="big">{d.image_count} images</div>
      <div>
        <span className="sev-high">{d.cves_high} high</span> ·{' '}
        <span className="sev-medium">{d.cves_medium} med</span> ·{' '}
        <span className="sev-low">{d.cves_low} low</span>
      </div>
    </div>
  );
}

export default function App() {
  const { images, stats, refresh } = useImages();
  const [form, setForm] = useState({
    name: '', tag: 'latest', base_flavor: 'chainguard',
    cves_high: 0, cves_medium: 0, cves_low: 0,
  });

  const submit = async (e) => {
    e.preventDefault();
    await fetch(`${API}/api/images`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...form,
        cves_high: +form.cves_high,
        cves_medium: +form.cves_medium,
        cves_low: +form.cves_low,
      }),
    });
    setForm({ ...form, name: '' });
    refresh();
  };

  const remove = async (id) => {
    await fetch(`${API}/api/images/${id}`, { method: 'DELETE' });
    refresh();
  };

  return (
    <>
      <header>
        <h1>Secure Image Catalog</h1>
        <small>JFrog Artifactory + Chainguard — Better Together POC</small>
      </header>
      <main>
        <div className="cards">
          <StatCard flavor="chainguard" data={stats.chainguard} />
          <StatCard flavor="baseline"   data={stats.baseline} />
        </div>

        <form onSubmit={submit}>
          <input required placeholder="image name (e.g. catalog-api)"
                 value={form.name}
                 onChange={e => setForm({ ...form, name: e.target.value })} />
          <input placeholder="tag" value={form.tag}
                 onChange={e => setForm({ ...form, tag: e.target.value })} />
          <select value={form.base_flavor}
                  onChange={e => setForm({ ...form, base_flavor: e.target.value })}>
            <option value="chainguard">chainguard</option>
            <option value="baseline">baseline</option>
          </select>
          <input type="number" min="0" placeholder="high" style={{ width: 80 }}
                 value={form.cves_high}
                 onChange={e => setForm({ ...form, cves_high: e.target.value })} />
          <input type="number" min="0" placeholder="med" style={{ width: 80 }}
                 value={form.cves_medium}
                 onChange={e => setForm({ ...form, cves_medium: e.target.value })} />
          <input type="number" min="0" placeholder="low" style={{ width: 80 }}
                 value={form.cves_low}
                 onChange={e => setForm({ ...form, cves_low: e.target.value })} />
          <button type="submit">Add image</button>
        </form>

        <table>
          <thead>
            <tr>
              <th>ID</th><th>Name</th><th>Tag</th><th>Flavor</th>
              <th>High</th><th>Med</th><th>Low</th><th>Scanned</th><th></th>
            </tr>
          </thead>
          <tbody>
            {images.map(img => (
              <tr key={img.id}>
                <td>{img.id}</td>
                <td>{img.name}</td>
                <td>{img.tag}</td>
                <td><span className={`pill ${img.base_flavor}`}>{img.base_flavor}</span></td>
                <td className="sev-high">{img.cves_high}</td>
                <td className="sev-medium">{img.cves_medium}</td>
                <td className="sev-low">{img.cves_low}</td>
                <td>{img.last_scanned ? new Date(img.last_scanned).toLocaleString() : '—'}</td>
                <td><button className="danger" onClick={() => remove(img.id)}>Delete</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </main>
    </>
  );
}
