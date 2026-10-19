/**
 * OKR 数据模型与通用工具
 */

export enum OkrPriority {
  Low = 0,
  Medium = 1,
  High = 2
}

export interface OkrTagItem {
  name: string;
  colorIndex: number;
}

export interface OkrProjectItem {
  id: string;
  title: string;
  desc: string;
  colorIndex: number;
  archived: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface OkrIdeaItem {
  id: string;
  title: string;
  note: string;
  tags: string[];
  priority: number;
  dueDate: number;
  krId: string;
  projectId: string;
  done: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface OkrKrItem {
  id: string;
  objectiveId: string;
  title: string;
  targetValue: string;
  dueDate: number;
  projectId: string;
  createdAt: number;
  updatedAt: number;
}

export interface OkrObjectiveItem {
  id: string;
  title: string;
  period: string;
  desc: string;
  projectId: string;
  createdAt: number;
  updatedAt: number;
}

export interface OkrSnapshot {
  ideas: OkrIdeaItem[];
  krs: OkrKrItem[];
  objectives: OkrObjectiveItem[];
  tags: OkrTagItem[];
  projects: OkrProjectItem[];
}

export interface OkrParsedText {
  title: string;
  tags: string[];
}

export interface OkrIdeaParam {
  ideaId: string;
}

export interface OkrKrParam {
  objectiveId: string;
  krId: string;
}

export interface OkrProjectParam {
  projectId: string;
}

export interface OkrObjectiveParam {
  objectiveId: string;
}

export const OKR_TAG_PALETTE: string[] = [
  '#4E7BFF',
  '#12B886',
  '#F59F00',
  '#E8590C',
  '#AE3EC9',
  '#1098AD',
  '#F03E3E',
  '#5C7CFA'
];

export function okrPriorityLabel(priority: number): string {
  if (priority >= OkrPriority.High) {
    return '高';
  }
  if (priority === OkrPriority.Medium) {
    return '中';
  }
  return '低';
}

export function okrPriorityColor(priority: number): string {
  if (priority >= OkrPriority.High) {
    return '#F03E3E';
  }
  if (priority === OkrPriority.Medium) {
    return '#F59F00';
  }
  return '#868E96';
}

export function okrTagColor(colorIndex: number): string {
  const size: number = OKR_TAG_PALETTE.length;
  const safe: number = size === 0 ? 0 : ((colorIndex % size) + size) % size;
  return OKR_TAG_PALETTE[safe];
}

export function okrHashTag(name: string): number {
  let hash: number = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) % 100000;
  }
  return hash;
}

/**
 * 从一段文本中解析出 #标签（支持中英文），并返回去掉标签后的正文。
 */
export function okrParseTags(text: string): OkrParsedText {
  const result: OkrParsedText = { title: '', tags: [] as string[] };
  const pattern: RegExp = /#([A-Za-z0-9_\u4e00-\u9fa5]+)/g;
  const seen: string[] = [];
  const body: string[] = [];
  let cursor: number = 0;
  let matched: RegExpExecArray | null = pattern.exec(text);
  while (matched !== null) {
    const raw: string = matched[0];
    const name: string = matched[1];
    if (!okrStringIncludes(seen, name)) {
      seen.push(name);
    }
    body.push(text.substring(cursor, matched.index));
    cursor = matched.index + raw.length;
    matched = pattern.exec(text);
  }
  body.push(text.substring(cursor));
  result.tags = seen;
  result.title = body.join(' ').replace(/\s+/g, ' ').trim();
  return result;
}

export function okrStringIncludes(source: string[], value: string): boolean {
  for (let i = 0; i < source.length; i++) {
    if (source[i] === value) {
      return true;
    }
  }
  return false;
}

export function okrNow(): number {
  return Date.now();
}

export function okrDay(offsetDays: number): number {
  const date: Date = new Date();
  date.setHours(0, 0, 0, 0);
  return date.getTime() + offsetDays * 86400000;
}

export function okrSameDay(left: number, right: number): boolean {
  if (left <= 0 || right <= 0) {
    return false;
  }
  return okrDayStart(left) === okrDayStart(right);
}

export function okrEmptyIdea(): OkrIdeaItem {
  return {
    id: '',
    title: '',
    note: '',
    tags: [],
    priority: 0,
    dueDate: 0,
    krId: '',
    projectId: '',
    done: false,
    createdAt: 0,
    updatedAt: 0
  };
}

export function okrNewId(prefix: string): string {
  const stamp: string = Date.now().toString(36);
  const rand: string = Math.floor(Math.random() * 46656).toString(36);
  return `${prefix}_${stamp}_${rand}`;
}

function okrPad2(value: number): string {
  if (value < 10) {
    return `0${value}`;
  }
  return `${value}`;
}

export function okrFormatDate(timestamp: number): string {
  if (timestamp <= 0) {
    return '';
  }
  const date: Date = new Date(timestamp);
  const month: number = date.getMonth() + 1;
  const day: number = date.getDate();
  return `${date.getFullYear()}-${okrPad2(month)}-${okrPad2(day)}`;
}

export function okrDueText(timestamp: number): string {
  if (timestamp <= 0) {
    return '无截止';
  }
  const today: number = okrTodayStart();
  const target: number = okrDayStart(timestamp);
  const diff: number = Math.round((target - today) / 86400000);
  const label: string = okrFormatDate(timestamp).substring(5);
  if (diff === 0) {
    return '今天到期';
  }
  if (diff === 1) {
    return '明天到期';
  }
  if (diff === -1) {
    return '昨天逾期';
  }
  if (diff < 0) {
    return `逾期${-diff}天`;
  }
  return `${label} 到期`;
}

export function okrIsOverdue(timestamp: number, done: boolean): boolean {
  if (done || timestamp <= 0) {
    return false;
  }
  return okrDayStart(timestamp) < okrTodayStart();
}

function okrDayStart(timestamp: number): number {
  const date: Date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function okrTodayStart(): number {
  return okrDayStart(Date.now());
}
