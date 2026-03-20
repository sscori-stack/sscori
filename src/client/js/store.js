const ST = {
  get(k, d = null) {
    try {
      const v = localStorage.getItem(k);
      return v ? JSON.parse(v) : d;
    } catch {
      return d;
    }
  },
  set(k, v) {
    try {
      localStorage.setItem(k, JSON.stringify(v));
    } catch { /* storage full or unavailable */ }
  }
};

export function getProg() { return ST.get('ebs_prog', {}); }
export function setProg(d) { ST.set('ebs_prog', d); }
export function getDont() { return ST.get('ebs_dont', []); }
export function setDont(d) { ST.set('ebs_dont', d); }
