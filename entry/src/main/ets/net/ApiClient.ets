import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface ApiAuthResult {
  token: string;
  userId: string;
  username: string;
  error: string;
  ok: boolean;
}

export interface ApiObjectiveItem {
  id: string;
  title: string;
  period: string;
  startDate: number;
  endDate: number;
  note: string;
  projectId: string;
  createdAt: number;
  updatedAt: number;
}

export interface ApiProjectItem {
  id: string;
  title: string;
  note: string;
  colorIndex: number;
  archived: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface ApiKrItem {
  id: string;
  objectiveId: string;
  title: string;
  targetValue: string;
  dueDate: number;
  projectId: string;
  createdAt: number;
  updatedAt: number;
}

export interface ApiIdeaItem {
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

export interface ApiTagItem {
  name: string;
  colorIndex: number;
  sortIndex: number;
}

export interface ApiReviewItem {
  id: string;
  objectiveId: string;
  weekKey: string;
  text: string;
  createdAt: number;
  updatedAt: number;
}

export interface ApiRemoved {
  objectives: string[];
  krs: string[];
  ideas: string[];
  tags: string[];
  projects: string[];
  reviews: string[];
}

export interface ApiPushBody {
  deviceId: string;
  objectives: ApiObjectiveItem[];
  krs: ApiKrItem[];
  ideas: ApiIdeaItem[];
  tags: ApiTagItem[];
  projects: ApiProjectItem[];
  reviews: ApiReviewItem[];
  removed: ApiRemoved;
}

export interface ApiConflictItem {
  entity: string;
  id: string;
}

export interface ApiPushResult {
  cursor: number;
  conflicts: ApiConflictItem[];
  error: string;
}

export interface ApiPullResult {
  cursor: number;
  hasMore: boolean;
  objectives: ApiObjectiveItem[];
  krs: ApiKrItem[];
  ideas: ApiIdeaItem[];
  tags: ApiTagItem[];
  projects: ApiProjectItem[];
  reviews: ApiReviewItem[];
  error: string;
}

interface RawAuth {
  token?: string;
  userId?: string;
  username?: string;
  error?: string;
}

interface RawObjective {
  id?: string;
  title?: string;
  period?: string;
  startDate?: number;
  endDate?: number;
  note?: string;
  projectId?: string;
  createdAt?: number;
  updatedAt?: number;
}

interface RawProject {
  id?: string;
  title?: string;
  note?: string;
  colorIndex?: number;
  archived?: boolean;
  createdAt?: number;
  updatedAt?: number;
}

interface RawKr {
  id?: string;
  objectiveId?: string;
  title?: string;
  targetValue?: string;
  dueDate?: number;
  projectId?: string;
  createdAt?: number;
  updatedAt?: number;
}

interface RawIdea {
  id?: string;
  title?: string;
  note?: string;
  tags?: string[];
  priority?: number;
  dueDate?: number;
  krId?: string;
  projectId?: string;
  done?: boolean;
  createdAt?: number;
  updatedAt?: number;
}

interface RawReview {
  id?: string;
  objectiveId?: string;
  weekKey?: string;
  text?: string;
  createdAt?: number;
  updatedAt?: number;
}

interface RawTag {
  name?: string;
  colorIndex?: number;
  sortIndex?: number;
}

interface RawConflict {
  entity?: string;
  id?: string;
}

interface RawPush {
  cursor?: number;
  conflicts?: RawConflict[];
}

interface RawPull {
  cursor?: number;
  hasMore?: boolean;
  objectives?: RawObjective[];
  krs?: RawKr[];
  ideas?: RawIdea[];
  tags?: RawTag[];
  projects?: RawProject[];
  reviews?: RawReview[];
}

interface CredentialsPayload {
  username: string;
  password: string;
}

class HttpReply {
  code: number = 0;
  body: string = '';
  constructor(code: number, body: string) {
    this.code = code;
    this.body = body;
  }
}

function s(value: string | undefined, fallback: string = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function n(value: number | undefined, fallback: number = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function toStrArray(value: string[] | undefined): string[] {
  const out: string[] = [];
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i++) {
      if (typeof value[i] === 'string') {
        out.push(value[i]);
      }
    }
  }
  return out;
}

function mapObjective(raw: RawObjective): ApiObjectiveItem | undefined {
  const id: string = s(raw.id);
  if (id.length === 0) {
    return undefined;
  }
  return {
    id: id,
    title: s(raw.title),
    period: s(raw.period),
    startDate: n(raw.startDate),
    endDate: n(raw.endDate),
    note: s(raw.note),
    projectId: s(raw.projectId),
    createdAt: n(raw.createdAt),
    updatedAt: n(raw.updatedAt)
  };
}

function mapProject(raw: RawProject): ApiProjectItem | undefined {
  const id: string = s(raw.id);
  if (id.length === 0) {
    return undefined;
  }
  return {
    id: id,
    title: s(raw.title),
    note: s(raw.note),
    colorIndex: n(raw.colorIndex),
    archived: raw.archived === true,
    createdAt: n(raw.createdAt),
    updatedAt: n(raw.updatedAt)
  };
}

function mapKr(raw: RawKr): ApiKrItem | undefined {
  const id: string = s(raw.id);
  if (id.length === 0) {
    return undefined;
  }
  return {
    id: id,
    objectiveId: s(raw.objectiveId),
    title: s(raw.title),
    targetValue: s(raw.targetValue),
    dueDate: n(raw.dueDate),
    projectId: s(raw.projectId),
    createdAt: n(raw.createdAt),
    updatedAt: n(raw.updatedAt)
  };
}

function mapIdea(raw: RawIdea): ApiIdeaItem | undefined {
  const id: string = s(raw.id);
  if (id.length === 0) {
    return undefined;
  }
  return {
    id: id,
    title: s(raw.title),
    note: s(raw.note),
    tags: toStrArray(raw.tags),
    priority: n(raw.priority, 1),
    dueDate: n(raw.dueDate),
    krId: s(raw.krId),
    projectId: s(raw.projectId),
    done: raw.done === true,
    createdAt: n(raw.createdAt),
    updatedAt: n(raw.updatedAt)
  };
}

function mapReview(raw: RawReview): ApiReviewItem | undefined {
  const id: string = s(raw.id);
  if (id.length === 0) {
    return undefined;
  }
  return {
    id: id,
    objectiveId: s(raw.objectiveId),
    weekKey: s(raw.weekKey),
    text: s(raw.text),
    createdAt: n(raw.createdAt),
    updatedAt: n(raw.updatedAt)
  };
}

function mapTag(raw: RawTag): ApiTagItem | undefined {
  const name: string = s(raw.name);
  if (name.length === 0) {
    return undefined;
  }
  return { name: name, colorIndex: n(raw.colorIndex), sortIndex: n(raw.sortIndex) };
}

async function request(url: string, method: http.RequestMethod, body: string, token: string): Promise<HttpReply> {
  const req: http.HttpRequest = http.createHttp();
  const header: Record<string, string> = {};
  if (body.length > 0) {
    header['Content-Type'] = 'application/json';
  }
  if (token.length > 0) {
    header['Authorization'] = `Bearer ${token}`;
  }
  try {
    const resp: http.HttpResponse = await req.request(url, {
      method: method,
      extraData: body,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 8000,
      readTimeout: 15000
    });
    const text: string = typeof resp.result === 'string' ? resp.result as string : '';
    return new HttpReply(resp.responseCode, text);
  } finally {
    req.destroy();
  }
}

function errText(err: BusinessError): string {
  if (err !== null && err !== undefined && typeof err.message === 'string' && err.message.length > 0) {
    return err.message;
  }
  return '网络连接失败';
}

function authReply(reply: HttpReply): ApiAuthResult {
  if (reply.code !== 200) {
    let message: string = reply.code === 409 ? '用户名已存在'
      : (reply.code === 401 ? '用户名或密码错误' : `服务异常 ${reply.code}`);
    try {
      const raw: RawAuth = JSON.parse(reply.body) as RawAuth;
      if (raw !== null && typeof raw.error === 'string' && (raw.error as string).length > 0) {
        message = raw.error as string;
      }
    } catch (err) {
      message = message;
    }
    return { token: '', userId: '', username: '', error: message, ok: false };
  }
  try {
    const raw: RawAuth = JSON.parse(reply.body) as RawAuth;
    const token: string = s(raw.token);
    const userId: string = s(raw.userId);
    if (token.length === 0 || userId.length === 0) {
      return { token: '', userId: '', username: '', error: '服务端返回异常', ok: false };
    }
    return { token: token, userId: userId, username: s(raw.username), error: '', ok: true };
  } catch (err) {
    return { token: '', userId: '', username: '', error: '响应解析失败', ok: false };
  }
}

export async function apiRegister(baseUrl: string, username: string, password: string): Promise<ApiAuthResult> {
  const payload: CredentialsPayload = { username: username, password: password };
  try {
    const reply: HttpReply = await request(`${baseUrl}/api/auth/register`, http.RequestMethod.POST,
      JSON.stringify(payload), '');
    return authReply(reply);
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    return { token: '', userId: '', username: '', error: errText(e), ok: false };
  }
}

export async function apiLogin(baseUrl: string, username: string, password: string): Promise<ApiAuthResult> {
  const payload: CredentialsPayload = { username: username, password: password };
  try {
    const reply: HttpReply = await request(`${baseUrl}/api/auth/login`, http.RequestMethod.POST,
      JSON.stringify(payload), '');
    return authReply(reply);
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    return { token: '', userId: '', username: '', error: errText(e), ok: false };
  }
}

function emptyPull(message: string): ApiPullResult {
  return {
    cursor: 0,
    hasMore: false,
    objectives: [],
    krs: [],
    ideas: [],
    tags: [],
    projects: [],
    reviews: [],
    error: message
  };
}

export async function apiPull(baseUrl: string, token: string, cursor: number): Promise<ApiPullResult> {
  try {
    const reply: HttpReply = await request(`${baseUrl}/api/sync?sinceSeq=${cursor}`, http.RequestMethod.GET, '', token);
    if (reply.code !== 200) {
      return emptyPull(reply.code === 401 ? '登录已失效' : `拉取失败 ${reply.code}`);
    }
    const raw: RawPull = JSON.parse(reply.body) as RawPull;
    const objectives: ApiObjectiveItem[] = [];
    const krs: ApiKrItem[] = [];
    const ideas: ApiIdeaItem[] = [];
    const tags: ApiTagItem[] = [];
    const projects: ApiProjectItem[] = [];
    const reviews: ApiReviewItem[] = [];
    if (Array.isArray(raw.projects)) {
      for (let i = 0; i < raw.projects.length; i++) {
        const item: ApiProjectItem | undefined = mapProject(raw.projects[i]);
        if (item !== undefined) {
          projects.push(item);
        }
      }
    }
    if (Array.isArray(raw.objectives)) {
      for (let i = 0; i < raw.objectives.length; i++) {
        const item: ApiObjectiveItem | undefined = mapObjective(raw.objectives[i]);
        if (item !== undefined) {
          objectives.push(item);
        }
      }
    }
    if (Array.isArray(raw.krs)) {
      for (let i = 0; i < raw.krs.length; i++) {
        const item: ApiKrItem | undefined = mapKr(raw.krs[i]);
        if (item !== undefined) {
          krs.push(item);
        }
      }
    }
    if (Array.isArray(raw.ideas)) {
      for (let i = 0; i < raw.ideas.length; i++) {
        const item: ApiIdeaItem | undefined = mapIdea(raw.ideas[i]);
        if (item !== undefined) {
          ideas.push(item);
        }
      }
    }
    if (Array.isArray(raw.tags)) {
      for (let i = 0; i < raw.tags.length; i++) {
        const item: ApiTagItem | undefined = mapTag(raw.tags[i]);
        if (item !== undefined) {
          tags.push(item);
        }
      }
    }
    if (Array.isArray(raw.reviews)) {
      for (let i = 0; i < raw.reviews.length; i++) {
        const item: ApiReviewItem | undefined = mapReview(raw.reviews[i]);
        if (item !== undefined) {
          reviews.push(item);
        }
      }
    }
    return {
      cursor: n(raw.cursor, cursor),
      hasMore: raw.hasMore === true,
      objectives: objectives,
      krs: krs,
      ideas: ideas,
      tags: tags,
      projects: projects,
      reviews: reviews,
      error: ''
    };
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    return emptyPull(errText(e));
  }
}

export async function apiPush(baseUrl: string, token: string, body: ApiPushBody): Promise<ApiPushResult> {
  try {
    const reply: HttpReply = await request(`${baseUrl}/api/sync`, http.RequestMethod.POST,
      JSON.stringify(body), token);
    if (reply.code !== 200) {
      return { cursor: 0, conflicts: [], error: reply.code === 401 ? '登录已失效' : `推送失败 ${reply.code}` };
    }
    const raw: RawPush = JSON.parse(reply.body) as RawPush;
    const conflicts: ApiConflictItem[] = [];
    if (Array.isArray(raw.conflicts)) {
      for (let i = 0; i < raw.conflicts.length; i++) {
        conflicts.push({ entity: s(raw.conflicts[i].entity), id: s(raw.conflicts[i].id) });
      }
    }
    return { cursor: n(raw.cursor), conflicts: conflicts, error: '' };
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    return { cursor: 0, conflicts: [], error: errText(e) };
  }
}

export async function apiHealth(baseUrl: string): Promise<string> {
  try {
    const reply: HttpReply = await request(`${baseUrl}/health`, http.RequestMethod.GET, '', '');
    return reply.code === 200 ? 'ok' : `HTTP ${reply.code}`;
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    return errText(e);
  }
}
