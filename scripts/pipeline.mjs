#!/usr/bin/env node
/**
 * speedtest-cdn — 一键全流程编排
 *
 * 流程:
 *   [1/3] 互联网发现   cdn-discovery.mjs   从多个来源发现新 CDN 测速链接
 *   [2/3] 检测与更新   update-cdn-nodes.mjs 检测 lib/servers.js 全部下载链接,
 *                                          死链自动从备用池替换(可用 --check-only 只检测)
 *   [3/3] 测速验证     verify-nodes.mjs    对更新后的节点实际测速, 输出验证报告
 *
 * 用法:
 *   node scripts/pipeline.mjs                 # 完整流程
 *   node scripts/pipeline.mjs --quick         # 快速模式(缩短测速时长/减少节点)
 *   node scripts/pipeline.mjs --check-only    # 只检测不修改 servers.js
 *   node scripts/pipeline.mjs --skip-discovery  # 跳过互联网发现
 *   node scripts/pipeline.mjs --nodes cdn-360,cdn-speedo  # 指定验证节点
 */

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '..');

const args = process.argv.slice(2);
const hasFlag = (f) => args.includes(f);
const getOpt = (f, def) => {
    const i = args.indexOf(f);
    return i !== -1 && args[i + 1] ? args[i + 1] : def;
};

const QUICK = hasFlag('--quick');
const CHECK_ONLY = hasFlag('--check-only');
const SKIP_DISCOVERY = hasFlag('--skip-discovery');
const ONLY_NODES = getOpt('--nodes', null);

const t0 = Date.now();
const results = [];

function run(script, extraArgs = []) {
    return new Promise((resolve) => {
        const child = spawn(process.execPath, [path.join(__dirname, script), ...extraArgs], {
            cwd: PROJECT_ROOT,
            stdio: 'inherit',
        });
        child.on('exit', (code) => resolve(code ?? 1));
        child.on('error', () => resolve(1));
    });
}

function banner(step, title) {
    console.log('\n' + '═'.repeat(64));
    console.log(`  [${step}/3] ${title}`);
    console.log('═'.repeat(64) + '\n');
}

async function main() {
    console.log('╔' + '═'.repeat(62) + '╗');
    console.log('║  speedtest-cdn — CDN 测速节点全流程维护' + ' '.repeat(22) + '║');
    console.log('║  发现 → 检测更新 → 测速验证' + ' '.repeat(35) + '║');
    console.log('╚' + '═'.repeat(62) + '╝');
    if (QUICK) console.log('⚡ 快速模式');
    if (CHECK_ONLY) console.log('🔍 仅检测模式 (不修改 servers.js)');
    console.log('');

    // ── [1/3] 互联网发现 ──
    if (!SKIP_DISCOVERY) {
        banner(1, '互联网 CDN 链接发现');
        const code = await run('cdn-discovery.mjs');
        results.push({ step: '发现', ok: code === 0 });
        if (code !== 0) console.log('⚠ 发现步骤异常, 继续后续步骤\n');
    } else {
        console.log('[1/3] 已跳过互联网发现 (--skip-discovery)\n');
        results.push({ step: '发现', ok: true, skipped: true });
    }

    // ── [2/3] 检测与更新 ──
    banner(2, CHECK_ONLY ? '节点链接健康检测 (仅检测)' : '节点链接健康检测与自动更新');
    const updateArgs = [];
    if (CHECK_ONLY) updateArgs.push('--check-only');
    if (hasFlag('--verbose')) updateArgs.push('--verbose');
    const code2 = await run('update-cdn-nodes.mjs', updateArgs);
    // update 脚本在"有死链无法全部替换"时返回 1, 这里只要报告生成即视为流程可继续
    results.push({ step: '检测更新', ok: true, code: code2 });

    // ── [3/3] 测速验证 ──
    banner(3, '更新后节点测速验证');
    const verifyArgs = [];
    if (QUICK) verifyArgs.push('--quick');
    if (ONLY_NODES) verifyArgs.push('--nodes', ONLY_NODES);
    const code3 = await run('verify-nodes.mjs', verifyArgs);
    results.push({ step: '测速验证', ok: code3 === 0 });

    // ── 汇总 ──
    const dt = ((Date.now() - t0) / 1000).toFixed(1);
    console.log('\n' + '═'.repeat(64));
    console.log('  全流程完成');
    console.log('═'.repeat(64));
    for (const r of results) {
        const mark = r.skipped ? '⏭' : r.ok ? '✅' : '❌';
        console.log(`  ${mark} ${r.step}${r.skipped ? ' (跳过)' : ''}`);
    }
    console.log(`  ⏱  总耗时: ${dt}s`);
    console.log('═'.repeat(64));

    const reportFile = path.join(PROJECT_ROOT, 'reports', 'last-report.json');
    if (fs.existsSync(reportFile)) {
        console.log(`  📋 检测报告: ${path.relative(PROJECT_ROOT, reportFile)}`);
    }
    const verifyFile = path.join(PROJECT_ROOT, 'reports', 'verify-report.json');
    if (fs.existsSync(verifyFile)) {
        console.log(`  📊 验证报告: ${path.relative(PROJECT_ROOT, verifyFile)}`);
    }
    console.log('');

    process.exit(results.some(r => !r.ok && !r.skipped) ? 1 : 0);
}

main().catch((e) => {
    console.error('❌ 全流程失败:', e.message);
    process.exit(1);
});
