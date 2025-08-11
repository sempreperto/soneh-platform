
const { Queue, Worker } = require('bullmq');
const Redis = require('ioredis');

const connection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

const q = new Queue('soneh-demo', { connection });

new Worker('soneh-demo', async job => {
  console.log('processing job', job.id, job.data);
}, { connection });

(async () => {
  await q.add('hello', { t: Date.now() });
  console.log('Worker online. Added demo job.');
})();
