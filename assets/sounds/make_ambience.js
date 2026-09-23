// Original deterministic synthesis, no samples or third-party recordings.
const fs = require('fs');
const output = process.argv[2] || __dirname;
fs.mkdirSync(output, { recursive: true });
const rate = 32000;
let seed = 29861;
function random() { seed = (1664525 * seed + 1013904223) >>> 0; return seed / 4294967296; }
function save(name, samples) {
 const data = Buffer.alloc(44 + samples.length * 2);
 data.write('RIFF'); data.writeUInt32LE(data.length - 8, 4); data.write('WAVEfmt ', 8);
 data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(1, 22);
 data.writeUInt32LE(rate, 24); data.writeUInt32LE(rate * 2, 28); data.writeUInt16LE(2, 32);
 data.writeUInt16LE(16, 34); data.write('data', 36); data.writeUInt32LE(samples.length * 2, 40);
 let peak=0; for(const sample of samples) peak=Math.max(peak,Math.abs(sample));
 const gain=.72/peak;
 for(let i=0;i<samples.length;i++) data.writeInt16LE(Math.round(samples[i]*gain*32767),44+i*2);
 fs.writeFileSync(require('path').join(output, name+'.wav'),data);
 console.log(name+': '+(samples.length/rate)+' seconds, peak -2.85 dBFS, mono 32 kHz PCM');
}
const source = new Float64Array(rate * 32);
let low=0, high=0;
for(let i=0;i<source.length;i++) {
 const noise=random()*2-1,t=i/rate;
 low+=.022*(noise-low); high+=.16*(noise-high);
 const swell=.55+.18*Math.sin(t*.53)+.11*Math.sin(t*1.21);
 source[i]=(low*.85+high*.15)*swell;
}
// Overlap the last four seconds with the first four; loop closes at sample 4s.
const cross=rate*4, length=source.length-cross;
const wind=new Float64Array(length);
for(let i=0;i<length;i++) {
 const src=i+cross;
 if(src<length) wind[i]=source[src];
 else { const blend=(src-length)/cross; wind[i]=source[src]*(1-blend)+source[src-length]*blend; }
}
save('NinjaCoyo_wind',wind);
const chimes=new Float64Array(rate*9);
const notes=[[0,784],[.55,1046.5],[1.45,1174.7],[2.2,1568],[3.4,1046.5],[4.4,1318.5]];
for(const [start,freq] of notes) {
 for(let i=Math.floor(start*rate);i<chimes.length;i++) {
  const t=i/rate-start,env=(1-Math.exp(-t*100))*Math.exp(-t*1.15);
  chimes[i]+=env*(Math.sin(2*Math.PI*freq*t)+.32*Math.sin(2*Math.PI*freq*2.756*t)*Math.exp(-t*1.1)+.15*Math.sin(2*Math.PI*freq*5.404*t)*Math.exp(-t*2));
 }
}
for(let i=chimes.length-rate;i<chimes.length;i++)chimes[i]*=(chimes.length-i)/rate;
save('NinjaCoyo_chimes',chimes);
