/**
 * OKR 进度分析：应达线推算、状态判定、周期刻度
 * 视觉语言参考「极简卡片版 · 白瓷 Porcelain」——状态由填充色承担，进度条上有一根应达线游标。
 */

/** 进度状态：填充色直接承担状态，不再需要状态徽章 */
export enum OkrFlowState {
  /** 推进中 · 实际 ≥ 应达 */
  OnTrack = 0,
  /** 停滞 · 连续多日没有更新 */
  Stalled = 1,
  /** 落后 · 实际 < 应达 */
  Behind = 2
}

/** 停滞判定阈值：多少天没有任何进展算停滞 */
export const OKR_STALL_DAYS: number = 7;

const DAY_MS: number = 86400000;

function okrDayFloor(timestamp: number): number {
  const date: Date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

/**
 * 按时间线性推算「应达百分比」。
 * 没有起止日期时返回 -1，表示这条 KR 没有可推算的节奏。
 */
export function okrExpectedPercent(startDate: number, endDate: number, now: number): number {
  if (startDate <= 0 || endDate <= startDate) {
    return -1;
  }
  if (now <= startDate) {
    return 0;
  }
  if (now >= endDate) {
    return 100;
  }
  const ratio: number = (now - startDate) / (endDate - startDate);
  return Math.round(ratio * 100);
}

/** 距上次更新的天数 */
export function okrIdleDays(lastUpdatedAt: number, now: number): number {
  if (lastUpdatedAt <= 0) {
    return OKR_STALL_DAYS + 1;
  }
  const diff: number = okrDayFloor(now) - okrDayFloor(lastUpdatedAt);
  return Math.max(0, Math.round(diff / DAY_MS));
}

/**
 * 状态判定：先看有没有停滞，再比实际与应达。
 */
export function okrFlowState(actual: number, expected: number, idleDays: number): OkrFlowState {
  if (idleDays >= OKR_STALL_DAYS) {
    return OkrFlowState.Stalled;
  }
  if (expected < 0) {
    return OkrFlowState.OnTrack;
  }
  if (actual < expected) {
    return OkrFlowState.Behind;
  }
  return OkrFlowState.OnTrack;
}

/** 状态对应的填充色 */
export function okrFlowColor(state: OkrFlowState): string {
  if (state === OkrFlowState.Behind) {
    return '#C0402C';
  }
  if (state === OkrFlowState.Stalled) {
    return '#A7B0B7';
  }
  return '#2F55D4';
}

/** 状态对应的文字色（状态行「领先 28% / 落后 15% / 9 天未更新」） */
export function okrFlowText(state: OkrFlowState): string {
  if (state === OkrFlowState.Behind) {
    return '#C0402C';
  }
  if (state === OkrFlowState.Stalled) {
    return '#949DA5';
  }
  return '#2F55D4';
}

/** 状态标签文案 */
export function okrFlowLabel(state: OkrFlowState, actual: number, expected: number): string {
  if (state === OkrFlowState.Stalled) {
    return '进度停滞';
  }
  if (expected < 0) {
    return '推进中';
  }
  const gap: number = actual - expected;
  if (gap >= 0) {
    return `领先 ${gap}%`;
  }
  return `落后 ${-gap}%`;
}

/** ISO 周序号键，形如 2026-W42 */
export function okrWeekKey(timestamp: number): string {
  const date: Date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  // ISO：以周四定年
  date.setDate(date.getDate() + 3 - ((date.getDay() + 6) % 7));
  const year: number = date.getFullYear();
  const firstThursday: Date = new Date(year, 0, 4);
  firstThursday.setDate(firstThursday.getDate() + 3 - ((firstThursday.getDay() + 6) % 7));
  const week: number = 1 + Math.round((date.getTime() - firstThursday.getTime()) / (7 * DAY_MS));
  return `${year}-W${week < 10 ? '0' + week : week}`;
}

/** 周键取周序号，如 2026-W42 → 42 */
export function okrWeekNumber(weekKey: string): number {
  const index: number = weekKey.indexOf('-W');
  if (index < 0) {
    return 0;
  }
  const parsed: number = Number(weekKey.substring(index + 2));
  return isNaN(parsed) ? 0 : parsed;
}

/** 季度刻度尺：把 start~end 均分成 totalWeeks 周，返回「今天」所在位置百分比 */
export function okrQuarterTick(startDate: number, endDate: number, now: number): number {
  if (startDate <= 0 || endDate <= startDate) {
    return 0;
  }
  if (now <= startDate) {
    return 0;
  }
  if (now >= endDate) {
    return 100;
  }
  return Math.round(((now - startDate) / (endDate - startDate)) * 100);
}

/** 季度总周数（向上取整） */
export function okrTotalWeeks(startDate: number, endDate: number): number {
  if (startDate <= 0 || endDate <= startDate) {
    return 0;
  }
  return Math.max(1, Math.ceil((endDate - startDate) / (7 * DAY_MS)));
}

/** 季度标签，如 2026 Q4 */
export function okrQuarterLabel(startDate: number): string {
  if (startDate <= 0) {
    return '';
  }
  const date: Date = new Date(startDate);
  const quarter: number = Math.floor(date.getMonth() / 3) + 1;
  return `${date.getFullYear()} Q${quarter}`;
}

/** 中文星期 */
export function okrWeekdayLabel(timestamp: number): string {
  const names: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return names[new Date(timestamp).getDay()];
}

/** 完整度百分比的安全夹取 */
export function okrClampPercent(value: number): number {
  if (value < 0) {
    return 0;
  }
  if (value > 100) {
    return 100;
  }
  return value;
}
