#!/usr/bin/env node
/**
 * speedtest-cdn — 节点测速验证
 *
 * 读取 lib/servers.js 的 CDN_SERVERS, 对每个节点执行真实测速(HTTP 多流下载),
 * 输出控制台表格 + reports/verify-report.json。
 *
 * 用法:
 *   node scripts/verify-nodes.mjs                 # 验证全部节点
 *   node scripts/verify-nodes.mjs --quick         # 快速模式(6s 窗口, 4 流)
 *   node scripts/verify-nodes.mjs --nodes cdn-360,cdn-speedo
 *   node scripts/verify-nodes.mjs --streams 8 --duration 10
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runCdnSpeedtest } from '../lib/cdnSpeedtest.js';
import { CDN_SERVERS, CDN_UPLOAD_URLS } from '../lib/servers.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '..');

const args = process.argv.slice(2);
const getOpt = (f, def) => {
    const i = args.indexOf(f);
    return i !== -1 && args[i + 1] ? args[i + 1] : def;
};
const QUICK = args.includes('--quick');
const ONLY = getOpt('--nodes', null);
const STREAMS = parseInt(getOpt('--streams', QUICK ? '4' : '6'), 10);
const DURATION = parseInt(getOpt('--duration', QUICK ? '6' : '8'), 10);

function pad(s, n) {
    s = String(s);
    const w = [...s].reduce((a, c) => a + (c.charCodeAt(0) > 255 ? 2 : 1), 0);
    return s + ' '.repeat(Math.max(0, n - w));
}

// 快速模式默认验证的代表性子集（覆盖共享池/源池/保底/单源四类）
const QUICK_SUBSET = ['cdn-cloudflare-25m', 'cdn-baidu', 'cdn-speedo', 'cdn-360', 'cdn-tencent'];

async function main() {
    // 选择节点
    let ids = Object.keys(CDN_SERVERS);
    if (ONLY) {
        const wanted = ONLY.split(',').map(s => s.trim()).filter(Boolean);
        ids = ids.filter(id => wanted.includes(id));
        if (ids.length === 0) {
            console.error(`❌ 未匹配到节点: ${ONLY}`);
            console.error(`   可用: ${Object.keys(CDN_SERVERS).join(', ')}`);
            process.exit(1);
        }
    } else if (QUICK) {
        // 快速模式: 仅验证代表性子集, 避免全量耗时
        const subset = QUICK_SUBSET.filter(id => ids.includes(id));
        if (subset.length) ids = subset;
    }

    console.log('═'.repeat(72));
    console.log('  CDN 节点测速验证');
    console.log(`  节点数: ${ids.length} | 每节点: ${STREAMS} 流 × ${DURATION}s${QUICK ? ' (快速模式)' : ''}`);
    console.log('═'.repeat(72) + '\n');

    const results = [];
    for (const id of ids) {
        const node = CDN_SERVERS[id];
        const cfg = {
            name: node.name,
            downloadUrl: node.downloadUrl,
            downloadUrls: node.downloadUrls,
            fallbackDownloadUrl: node.fallbackDownloadUrl,
            uploadUrls: node.uploadUrls || CDN_UPLOAD_URLS,
            pingUrl: node.pingUrl || node.downloadUrls?.[0] || node.downloadUrl,
            streams: Math.min(node.streams || STREAMS, STREAMS),
            downloadTime: DURATION,
            uploadTime: Math.min(DURATION, 6),
        };

        const srcDesc = cfg.downloadUrls
            ? `${cfg.downloadUrls.length}源池${cfg.fallbackDownloadUrl ? '+保底' : ''}`
            : (cfg.downloadUrl || '').replace(/^https?:\/\//, '').slice(0, 40);

        process.stdout.write(`⏳ ${pad(node.name, 28)} ${pad(srcDesc, 30)}`);

        const t0 = Date.now();
        try {
            const r = await runCdnSpeedtest(cfg);
            const dt = ((Date.now() - t0) / 1000).toFixed(1);
            const ok = r.download > 0;
            console.log(` ${ok ? '✅' : '⚠️ '} 下载 ${pad(r.download.toFixed(1), 8)} Mbps  上传 ${pad(r.upload.toFixed(1), 7)} Mbps  ${dt}s`);
            results.push({
                id, name: node.name, ok,
                downloadMbps: r.download, uploadMbps: r.upload,
                downloadMB: +(r.downloadBytes / 1e6).toFixed(1),
                uploadMB: +(r.uploadBytes / 1e6).toFixed(1),
                pingMs: r.ping, elapsedSec: +dt,
                source: cfg.downloadUrls ? `${cfg.downloadUrls.length}源池` : cfg.downloadUrl,
                fallback: !!cfg.fallbackDownloadUrl,
            });
        } catch (e) {
            const dt = ((Date.now() - t0) / 1000).toFixed(1);
            console.log(` ❌ ${e.message.slice(0, 60)} (${dt}s)`);
            results.push({ id, name: node.name, ok: false, error: e.message, elapsedSec: +dt });
        }
    }

    // ── 汇总 ──
    const okList = results.filter(r => r.ok);
    const avgDl = okList.length ? okList.reduce((s, r) => s + r.downloadMbps, 0) / okList.length : 0;
    const avgUl = okList.length ? okList.reduce((s, r) => s + r.uploadMbps, 0) / okList.length : 0;

    console.log('\n' + '═'.repeat(72));
    console.log(`  ✅ 可用 ${okList.length}/${results.length}`);
    if (okList.length) {
        console.log(`  📊 平均下载 ${avgDl.toFixed(1)} Mbps | 平均上传 ${avgUl.toFixed(1)} Mbps`);
        const best = okList.reduce((a, b) => (a.downloadMbps > b.downloadMbps ? a : b));
        console.log(`  🏆 最快节点: ${best.name} (${best.downloadMbps.toFixed(1)} Mbps)`);
    }
    console.log('═'.repeat(72) + '\n');

    // ── 报告 ──
    const reportDir = path.join(PROJECT_ROOT, 'reports');
    if (!fs.existsSync(reportDir)) fs.mkdirSync(reportDir, { recursive: true });
    const report = {
        timestamp: new Date().toISOString(),
        summary: {
            total: results.length,
            ok: okList.length,
            avgDownloadMbps: +avgDl.toFixed(2),
            avgUploadMbps: +avgUl.toFixed(2),
        },
        results,
    };
    const outFile = path.join(reportDir, 'verify-report.json');
    fs.writeFileSync(outFile, JSON.stringify(report, null, 2), 'utf-8');
    console.log(`📊 验证报告已保存: ${path.relative(PROJECT_ROOT, outFile)}\n`);

    process.exit(okList.length > 0 ? 0 : 1);
}

main().catch((e) => {
    console.error('❌ 验证失败:', e.message);
    process.exit(1);
});
