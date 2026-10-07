
export const labels={analysis:'En analyse',released:'Libéré',blocked:'Bloqué',draft:'Brouillon',confirmed:'Confirmée',shipped:'Expédiée',cancelled:'Annulée',owner:'Propriétaire',manager:'Gestionnaire',viewer:'Lecture seule'};
export const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');};
export const kg=n=>new Intl.NumberFormat('fr-FR',{maximumFractionDigits:3}).format(Number(n||0)/1000)+' kg';
export const money=(n,c='EUR')=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:c}).format(Number(n||0)/(c==='EUR'?100:1));
export const date=s=>s?new Intl.DateTimeFormat('fr-FR').format(new Date(s.length===10?s+'T12:00:00':s)):'—';
export function priceToMinor(value,currency){if(value===''||value==null)throw Error('Indiquez un prix.');const n=Number(value)*(currency==='EUR'?100:1);if(!Number.isFinite(n)||n<0||n>10000000)throw Error('Prix invalide.');return Math.round(n);}
export const lineTotal=(g,price)=>Math.round(Number(g)*Number(price)/1000);
export function csv(rows){return '\ufeff'+rows.map(row=>row.map(value=>{let s=String(value??'');if(/^\s*[=+@-]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';}).join(';')).join('\r\n');}
export function download(name,content,type){const url=URL.createObjectURL(new Blob([content],{type}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
