const fs = require('fs');
const path = require('path');
const axios = require('axios').default;

function usage(exitCode) {
  const msg = [
    'Usage:',
    '  node mass_role.js grant <roleId> [--guild <guildId>] [--out <file>]',
    '  node mass_role.js revoke <roleId> --in <file> [--guild <guildId>]',
    '  node mass_role.js strip <keepRoleId> [--guild <guildId>] [--out <file>] [--include-bots] [--remove-managed]',
    '  node mass_role.js restore --in <file> [--guild <guildId>] [--include-bots]',
    '',
    'Notes:',
    '  - Reads bot token from ./config.json (discordData.token).',
    '  - Bot must have: Manage Roles, and role must be below bot highest role.',
    '  - Bot must have Server Members Intent enabled to list members.',
  ].join('\n');
  console.error(msg);
  process.exit(exitCode);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const cur = argv[i];
    if (cur === '--guild') args.guild = argv[++i];
    else if (cur === '--out') args.out = argv[++i];
    else if (cur === '--in') args.in = argv[++i];
    else if (cur.startsWith('--')) usage(2);
    else args._.push(cur);
  }
  return args;
}

async function requestWithRetry(fn, label) {
  // Basic 429 handler for Discord REST.
  for (let attempt = 0; attempt < 10; attempt++) {
    try {
      return await fn();
    } catch (err) {
      const status = err?.response?.status;
      if (status === 429) {
        const retryAfterHeader = err.response.headers?.['retry-after'];
        const retryAfterBodyMs = Math.ceil((err.response.data?.retry_after ?? 1) * 1000);
        const retryAfterHeaderMs = retryAfterHeader ? Math.ceil(Number(retryAfterHeader) * 1000) : 0;
        const waitMs = Math.max(retryAfterBodyMs, retryAfterHeaderMs, 1000) + 250;
        console.log(`[rate-limit] ${label}: sleeping ${waitMs}ms`);
        await sleep(waitMs);
        continue;
      }
      throw err;
    }
  }
  throw new Error(`Too many retries for ${label}`);
}

async function listAllMembers(guildId) {
  const members = [];
  let after = '0';

  while (true) {
    const res = await requestWithRetry(
      () => axios.get(`/guilds/${guildId}/members`, { params: { limit: 1000, after } }),
      `list members after=${after}`
    );
    const page = res.data || [];
    if (!Array.isArray(page) || page.length === 0) break;
    members.push(...page);
    after = page[page.length - 1].user?.id;
    if (!after) break;
    if (page.length < 1000) break;
  }

  return members;
}

async function listGuildRoles(guildId) {
  const res = await requestWithRetry(
    () => axios.get(`/guilds/${guildId}/roles`),
    'list guild roles'
  );
  const roles = Array.isArray(res.data) ? res.data : [];
  const byId = new Map();
  for (const role of roles) {
    if (role?.id) byId.set(role.id, role);
  }
  return byId;
}

async function grantRoleToAllMembers(guildId, roleId, outFile) {
  const members = await listAllMembers(guildId);
  console.log(`[grant] members fetched: ${members.length}`);

  const grantedUserIds = [];
  let alreadyHad = 0;
  let failed = 0;

  for (let i = 0; i < members.length; i++) {
    const member = members[i];
    const userId = member?.user?.id;
    if (!userId) continue;

    const roles = Array.isArray(member.roles) ? member.roles : [];
    if (roles.includes(roleId)) {
      alreadyHad++;
      continue;
    }

    try {
      await requestWithRetry(
        () => axios.put(`/guilds/${guildId}/members/${userId}/roles/${roleId}`),
        `grant role user=${userId}`
      );
      grantedUserIds.push(userId);
    } catch (err) {
      failed++;
      const status = err?.response?.status;
      const code = err?.response?.data?.code;
      console.log(`[grant] failed user=${userId} status=${status} code=${code ?? ''}`.trim());
    }

    // Gentle pacing to avoid per-route bucket exhaustion.
    if (i % 10 === 0) await sleep(250);
  }

  const payload = {
    guildId,
    roleId,
    createdAt: new Date().toISOString(),
    grantedUserIds
  };
  fs.writeFileSync(outFile, JSON.stringify(payload, null, 2));

  console.log(`[grant] added role to: ${grantedUserIds.length}`);
  console.log(`[grant] already had role: ${alreadyHad}`);
  console.log(`[grant] failed: ${failed}`);
  console.log(`[grant] saved: ${outFile}`);
}

async function revokeRoleFromFile(guildId, roleId, inFile) {
  const raw = fs.readFileSync(inFile, 'utf8');
  const payload = JSON.parse(raw);

  const userIds = Array.isArray(payload.grantedUserIds) ? payload.grantedUserIds : [];
  console.log(`[revoke] userIds to revoke: ${userIds.length}`);

  let removed = 0;
  let failed = 0;

  for (let i = 0; i < userIds.length; i++) {
    const userId = userIds[i];
    try {
      await requestWithRetry(
        () => axios.delete(`/guilds/${guildId}/members/${userId}/roles/${roleId}`),
        `revoke role user=${userId}`
      );
      removed++;
    } catch (err) {
      failed++;
      const status = err?.response?.status;
      const code = err?.response?.data?.code;
      console.log(`[revoke] failed user=${userId} status=${status} code=${code ?? ''}`.trim());
    }

    if (i % 10 === 0) await sleep(250);
  }

  console.log(`[revoke] removed role from: ${removed}`);
  console.log(`[revoke] failed: ${failed}`);
}

async function stripRolesToKeepRole(guildId, keepRoleId, outFile, options) {
  const includeBots = Boolean(options?.includeBots);
  const removeManaged = Boolean(options?.removeManaged);

  const members = await listAllMembers(guildId);
  console.log(`[strip] members fetched: ${members.length}`);

  const rolesById = await listGuildRoles(guildId);
  const managedRoleIds = new Set();
  for (const role of rolesById.values()) {
    if (role?.managed) managedRoleIds.add(role.id);
  }

  const backup = {
    guildId,
    keepRoleId,
    createdAt: new Date().toISOString(),
    includeBots,
    removeManaged,
    members: []
  };

  let skippedBots = 0;
  let changed = 0;
  let alreadyOk = 0;
  let failed = 0;

  for (let i = 0; i < members.length; i++) {
    const member = members[i];
    const userId = member?.user?.id;
    const isBot = Boolean(member?.user?.bot);
    if (!userId) continue;

    if (isBot && !includeBots) {
      skippedBots++;
      backup.members.push({ userId, roles: Array.isArray(member.roles) ? member.roles : [], skipped: 'bot' });
      continue;
    }

    const currentRoles = Array.isArray(member.roles) ? member.roles : [];
    backup.members.push({ userId, roles: currentRoles });

    const nextRoles = new Set();
    nextRoles.add(String(keepRoleId));
    if (!removeManaged) {
      for (const roleId of currentRoles) {
        if (managedRoleIds.has(roleId)) nextRoles.add(roleId);
      }
    }

    const currentSet = new Set(currentRoles);
    let same = currentSet.size === nextRoles.size;
    if (same) {
      for (const roleId of nextRoles) {
        if (!currentSet.has(roleId)) {
          same = false;
          break;
        }
      }
    }

    if (same) {
      alreadyOk++;
      continue;
    }

    try {
      await requestWithRetry(
        () => axios.patch(`/guilds/${guildId}/members/${userId}`, { roles: Array.from(nextRoles) }),
        `strip roles user=${userId}`
      );
      changed++;
    } catch (err) {
      failed++;
      const status = err?.response?.status;
      const code = err?.response?.data?.code;
      console.log(`[strip] failed user=${userId} status=${status} code=${code ?? ''}`.trim());
    }

    if (i % 5 === 0) await sleep(400);
  }

  fs.writeFileSync(outFile, JSON.stringify(backup, null, 2));
  console.log(`[strip] changed: ${changed}`);
  console.log(`[strip] already ok: ${alreadyOk}`);
  console.log(`[strip] skipped bots: ${skippedBots}`);
  console.log(`[strip] failed: ${failed}`);
  console.log(`[strip] backup saved: ${outFile}`);
}

async function restoreRolesFromBackup(guildId, inFile, options) {
  const includeBots = Boolean(options?.includeBots);
  const raw = fs.readFileSync(inFile, 'utf8');
  const backup = JSON.parse(raw);

  const members = Array.isArray(backup.members) ? backup.members : [];
  console.log(`[restore] entries: ${members.length}`);

  let restored = 0;
  let skippedBots = 0;
  let failed = 0;

  for (let i = 0; i < members.length; i++) {
    const entry = members[i];
    const userId = entry?.userId;
    const roles = Array.isArray(entry?.roles) ? entry.roles : [];
    if (!userId) continue;

    if (entry?.skipped === 'bot' && !includeBots) {
      skippedBots++;
      continue;
    }

    try {
      await requestWithRetry(
        () => axios.patch(`/guilds/${guildId}/members/${userId}`, { roles }),
        `restore roles user=${userId}`
      );
      restored++;
    } catch (err) {
      failed++;
      const status = err?.response?.status;
      const code = err?.response?.data?.code;
      console.log(`[restore] failed user=${userId} status=${status} code=${code ?? ''}`.trim());
    }

    if (i % 5 === 0) await sleep(400);
  }

  console.log(`[restore] restored: ${restored}`);
  console.log(`[restore] skipped bots: ${skippedBots}`);
  console.log(`[restore] failed: ${failed}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const [mode, roleId] = args._;
  if (!mode) usage(2);

  const configPath = path.join(__dirname, 'config.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = config?.discordData?.token;
  const guildId = args.guild || config?.discordData?.guild;
  if (!token || !guildId) {
    console.error('Missing discordData.token or discordData.guild in config.json (or provide --guild).');
    process.exit(2);
  }

  axios.defaults.baseURL = 'https://discord.com/api/v10';
  axios.defaults.headers = {
    Authorization: `Bot ${token}`,
    'Content-Type': 'application/json'
  };

  if (mode === 'grant') {
    if (!roleId) usage(2);
    const outFile =
      args.out ||
      path.join(__dirname, `temp-role-${roleId}-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    await grantRoleToAllMembers(guildId, roleId, outFile);
    return;
  }

  if (mode === 'revoke') {
    if (!roleId) usage(2);
    if (!args.in) {
      console.error('Missing --in <file> for revoke mode.');
      process.exit(2);
    }
    await revokeRoleFromFile(guildId, roleId, args.in);
    return;
  }

  if (mode === 'strip') {
    if (!roleId) usage(2);
    const outFile =
      args.out ||
      path.join(__dirname, `roles-backup-before-strip-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    await stripRolesToKeepRole(guildId, roleId, outFile, {
      includeBots: Boolean(args.includeBots),
      removeManaged: Boolean(args.removeManaged)
    });
    return;
  }

  if (mode === 'restore') {
    if (!args.in) {
      console.error('Missing --in <file> for restore mode.');
      process.exit(2);
    }
    await restoreRolesFromBackup(guildId, args.in, { includeBots: Boolean(args.includeBots) });
    return;
  }

  usage(2);
}

main().catch((err) => {
  const status = err?.response?.status;
  const code = err?.response?.data?.code;
  const msg = err?.response?.data?.message;
  console.error(`[fatal] status=${status ?? 'n/a'} code=${code ?? 'n/a'} message=${msg ?? err.message}`);
  process.exit(1);
});
