import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  OkrIdeaItem,
  OkrKrItem,
  OkrObjectiveItem,
  OkrParsedText,
  OkrSnapshot,
  OkrTagItem,
  okrHashTag,
  okrNewId,
  okrNow,
  okrParseTags,
  okrStringIncludes
} from '../model/OkrModel';

const DOMAIN: number = 0x0A01;
const PREF_NAME: string = 'okr_store_v1';
const KEY_SNAPSHOT: string = 'snapshot';

@ObservedV2
export class OkrStore {
  @Trace ideas: OkrIdeaItem[] = [];
  @Trace krs: OkrKrItem[] = [];
  @Trace objectives: OkrObjectiveItem[] = [];
  @Trace tags: OkrTagItem[] = [];
  @Trace activeTag: string = '';
  @Trace showDone: boolean = true;

  private pref: preferences.Preferences | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
      const raw: preferences.ValueType = await this.pref.get(KEY_SNAPSHOT, '');
      this.applyRaw(this.toText(raw));
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'OkrStore', 'load failed: %{public}s', e.message);
    }
    if (this.ideas.length === 0 && this.objectives.length === 0) {
      this.seed();
    }
  }

  private toText(raw: preferences.ValueType): string {
    if (typeof raw === 'string') {
      return raw;
    }
    return '';
  }

  // ---------- 查询 ----------

  findIdea(id: string): OkrIdeaItem | undefined {
    for (let i = 0; i < this.ideas.length; i++) {
      if (this.ideas[i].id === id) {
        return this.ideas[i];
      }
    }
    return undefined;
  }

  findKr(id: string): OkrKrItem | undefined {
    for (let i = 0; i < this.krs.length; i++) {
      if (this.krs[i].id === id) {
        return this.krs[i];
      }
    }
    return undefined;
  }

  findObjective(id: string): OkrObjectiveItem | undefined {
    for (let i = 0; i < this.objectives.length; i++) {
      if (this.objectives[i].id === id) {
        return this.objectives[i];
      }
    }
    return undefined;
  }

  krsOfObjective(objectiveId: string): OkrKrItem[] {
    return this.krs.filter((item: OkrKrItem): boolean => item.objectiveId === objectiveId);
  }

  ideasOfKr(krId: string): OkrIdeaItem[] {
    return this.ideas.filter((item: OkrIdeaItem): boolean => item.krId === krId);
  }

  krProgress(krId: string): number {
    const linked: OkrIdeaItem[] = this.ideasOfKr(krId);
    if (linked.length === 0) {
      return 0;
    }
    let doneCount: number = 0;
    for (let i = 0; i < linked.length; i++) {
      if (linked[i].done) {
        doneCount++;
      }
    }
    return Math.round((doneCount / linked.length) * 100);
  }

  krTitle(krId: string): string {
    const kr: OkrKrItem | undefined = this.findKr(krId);
    return kr === undefined ? '' : kr.title;
  }

  krObjectiveId(krId: string): string {
    const kr: OkrKrItem | undefined = this.findKr(krId);
    return kr === undefined ? '' : kr.objectiveId;
  }

  objectiveProgress(objectiveId: string): number {
    const list: OkrKrItem[] = this.krsOfObjective(objectiveId);
    if (list.length === 0) {
      return 0;
    }
    let sum: number = 0;
    for (let i = 0; i < list.length; i++) {
      sum += this.krProgress(list[i].id);
    }
    return Math.round(sum / list.length);
  }

  tagNames(): string[] {
    const names: string[] = [];
    for (let i = 0; i < this.tags.length; i++) {
      names.push(this.tags[i].name);
    }
    return names;
  }

  tagColorIndex(name: string): number {
    for (let i = 0; i < this.tags.length; i++) {
      if (this.tags[i].name === name) {
        return this.tags[i].colorIndex;
      }
    }
    return okrHashTag(name);
  }

  visibleIdeas(): OkrIdeaItem[] {
    const list: OkrIdeaItem[] = this.ideas.filter((item: OkrIdeaItem): boolean => {
      if (!this.showDone && item.done) {
        return false;
      }
      if (this.activeTag.length > 0 && !okrStringIncludes(item.tags, this.activeTag)) {
        return false;
      }
      return true;
    });
    return list.sort((a: OkrIdeaItem, b: OkrIdeaItem): number => {
      if (a.done !== b.done) {
        return a.done ? 1 : -1;
      }
      if (a.priority !== b.priority) {
        return b.priority - a.priority;
      }
      return b.createdAt - a.createdAt;
    });
  }

  todoCount(): number {
    let count: number = 0;
    for (let i = 0; i < this.ideas.length; i++) {
      if (!this.ideas[i].done) {
        count++;
      }
    }
    return count;
  }

  doneTodayCount(): number {
    const date: Date = new Date();
    date.setHours(0, 0, 0, 0);
    const start: number = date.getTime();
    let count: number = 0;
    for (let i = 0; i < this.ideas.length; i++) {
      if (this.ideas[i].done && this.ideas[i].updatedAt >= start) {
        count++;
      }
    }
    return count;
  }

  // ---------- 想法 ----------

  addIdea(text: string, priority: number, dueDate: number): OkrIdeaItem {
    const parsed: OkrParsedText = okrParseTags(text);
    const now: number = okrNow();
    const idea: OkrIdeaItem = {
      id: okrNewId('idea'),
      title: parsed.title.length > 0 ? parsed.title : text.trim(),
      note: '',
      tags: parsed.tags,
      priority: priority,
      dueDate: dueDate,
      krId: '',
      done: false,
      createdAt: now,
      updatedAt: now
    };
    this.registerTags(parsed.tags);
    this.ideas = [idea].concat(this.ideas);
    this.persist();
    return idea;
  }

  saveIdea(idea: OkrIdeaItem): void {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      if (this.ideas[i].id === idea.id) {
        const copy: OkrIdeaItem = {
          id: idea.id,
          title: idea.title,
          note: idea.note,
          tags: idea.tags,
          priority: idea.priority,
          dueDate: idea.dueDate,
          krId: idea.krId,
          done: idea.done,
          createdAt: idea.createdAt,
          updatedAt: okrNow()
        };
        next.push(copy);
      } else {
        next.push(this.ideas[i]);
      }
    }
    this.registerTags(idea.tags);
    this.ideas = next;
    this.persist();
  }

  toggleIdeaDone(id: string): void {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      if (source.id === id) {
        next.push(this.cloneIdea(source, !source.done, source.updatedAt, source.krId));
      } else {
        next.push(source);
      }
    }
    this.ideas = next;
    this.persist();
  }

  deleteIdea(id: string): void {
    this.ideas = this.ideas.filter((item: OkrIdeaItem): boolean => item.id !== id);
    this.persist();
  }

  linkIdeaToKr(ideaId: string, krId: string): void {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      if (source.id === ideaId) {
        next.push(this.cloneIdea(source, source.done, okrNow(), krId));
      } else {
        next.push(source);
      }
    }
    this.ideas = next;
    this.persist();
  }

  private cloneIdea(source: OkrIdeaItem, done: boolean, updatedAt: number, krId: string): OkrIdeaItem {
    return {
      id: source.id,
      title: source.title,
      note: source.note,
      tags: source.tags,
      priority: source.priority,
      dueDate: source.dueDate,
      krId: krId,
      done: done,
      createdAt: source.createdAt,
      updatedAt: updatedAt
    };
  }

  // ---------- 目标与 KR ----------

  addObjective(title: string, period: string, desc: string): OkrObjectiveItem {
    const item: OkrObjectiveItem = {
      id: okrNewId('obj'),
      title: title,
      period: period,
      desc: desc,
      createdAt: okrNow()
    };
    this.objectives = [item].concat(this.objectives);
    this.persist();
    return item;
  }

  addKr(objectiveId: string, title: string, targetValue: string, dueDate: number): OkrKrItem {
    const item: OkrKrItem = {
      id: okrNewId('kr'),
      objectiveId: objectiveId,
      title: title,
      targetValue: targetValue,
      dueDate: dueDate,
      createdAt: okrNow()
    };
    this.krs = [item].concat(this.krs);
    this.persist();
    return item;
  }

  updateKr(kr: OkrKrItem): void {
    const next: OkrKrItem[] = [];
    for (let i = 0; i < this.krs.length; i++) {
      if (this.krs[i].id === kr.id) {
        next.push({
          id: kr.id,
          objectiveId: kr.objectiveId,
          title: kr.title,
          targetValue: kr.targetValue,
          dueDate: kr.dueDate,
          createdAt: kr.createdAt
        });
      } else {
        next.push(this.krs[i]);
      }
    }
    this.krs = next;
    this.persist();
  }

  deleteKr(krId: string): void {
    this.krs = this.krs.filter((item: OkrKrItem): boolean => item.id !== krId);
    this.unlinkKr(krId);
    this.persist();
  }

  deleteObjective(objectiveId: string): void {
    const krIds: string[] = [];
    const keptKrs: OkrKrItem[] = [];
    for (let i = 0; i < this.krs.length; i++) {
      if (this.krs[i].objectiveId === objectiveId) {
        krIds.push(this.krs[i].id);
      } else {
        keptKrs.push(this.krs[i]);
      }
    }
    this.krs = keptKrs;
    for (let i = 0; i < krIds.length; i++) {
      this.unlinkKr(krIds[i]);
    }
    this.objectives = this.objectives.filter((item: OkrObjectiveItem): boolean => item.id !== objectiveId);
    this.persist();
  }

  private unlinkKr(krId: string): void {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      if (source.krId === krId) {
        next.push(this.cloneIdea(source, source.done, source.updatedAt, ''));
      } else {
        next.push(source);
      }
    }
    this.ideas = next;
  }

  // ---------- 标签 ----------

  setActiveTag(name: string): void {
    this.activeTag = this.activeTag === name ? '' : name;
  }

  private registerTags(names: string[]): void {
    if (names.length === 0) {
      return;
    }
    const next: OkrTagItem[] = this.tags.slice();
    for (let i = 0; i < names.length; i++) {
      const name: string = names[i];
      if (name.length === 0) {
        continue;
      }
      let exists: boolean = false;
      for (let j = 0; j < next.length; j++) {
        if (next[j].name === name) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        const tag: OkrTagItem = { name: name, colorIndex: okrHashTag(name) };
        next.push(tag);
      }
    }
    this.tags = next;
  }

  // ---------- 持久化 ----------

  private applyRaw(raw: string): void {
    if (raw.length === 0) {
      return;
    }
    try {
      const data: OkrSnapshot = JSON.parse(raw) as OkrSnapshot;
      if (data === null || data === undefined) {
        return;
      }
      if (data.ideas !== undefined && data.ideas !== null) {
        this.ideas = data.ideas;
      }
      if (data.krs !== undefined && data.krs !== null) {
        this.krs = data.krs;
      }
      if (data.objectives !== undefined && data.objectives !== null) {
        this.objectives = data.objectives;
      }
      if (data.tags !== undefined && data.tags !== null) {
        this.tags = data.tags;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'OkrStore', 'parse failed: %{public}s', JSON.stringify(err));
    }
  }

  private persist(): void {
    const snapshot: OkrSnapshot = {
      ideas: this.ideas,
      krs: this.krs,
      objectives: this.objectives,
      tags: this.tags
    };
    try {
      if (this.pref !== undefined) {
        this.pref.put(KEY_SNAPSHOT, JSON.stringify(snapshot)).then(() => {
          this.pref?.flush();
        }).catch((err: BusinessError) => {
          hilog.error(DOMAIN, 'OkrStore', 'save failed: %{public}s', err.message);
        });
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'OkrStore', 'save error: %{public}s', e.message);
    }
  }

  private seed(): void {
    const now: number = okrNow();
    const day: number = 86400000;
    const objective: OkrObjectiveItem = {
      id: okrNewId('obj'),
      title: '打造个人 OKR 闭环',
      period: '本季度',
      desc: '把零散灵感沉淀成可追踪的目标与关键结果',
      createdAt: now
    };
    const kr1: OkrKrItem = {
      id: okrNewId('kr'),
      objectiveId: objective.id,
      title: '上线 OKR 记录 App 并坚持使用',
      targetValue: '连续记录 30 天',
      dueDate: now + 30 * day,
      createdAt: now
    };
    const kr2: OkrKrItem = {
      id: okrNewId('kr'),
      objectiveId: objective.id,
      title: '每周复盘一次关键结果进度',
      targetValue: '每周 1 次，共 12 周',
      dueDate: now + 84 * day,
      createdAt: now
    };
    this.objectives = [objective];
    this.krs = [kr1, kr2];
    this.ideas = [];
    this.tags = [];
    this.registerTags(['工作', '产品', '成长']);
    const idea1: OkrIdeaItem = {
      id: okrNewId('idea'),
      title: '把想法收件箱的输入框做顺手',
      note: '支持回车直接落库，标签写在正文里',
      tags: ['产品'],
      priority: 2,
      dueDate: now + 2 * day,
      krId: kr1.id,
      done: false,
      createdAt: now,
      updatedAt: now
    };
    const idea2: OkrIdeaItem = {
      id: okrNewId('idea'),
      title: '整理上周客户反馈',
      note: '',
      tags: ['工作'],
      priority: 1,
      dueDate: now + day,
      krId: '',
      done: false,
      createdAt: now - day,
      updatedAt: now - day
    };
    const idea3: OkrIdeaItem = {
      id: okrNewId('idea'),
      title: '读 30 分钟 OKR 方法论',
      note: '',
      tags: ['成长'],
      priority: 0,
      dueDate: 0,
      krId: kr2.id,
      done: true,
      createdAt: now - 2 * day,
      updatedAt: now - day
    };
    this.ideas = [idea1, idea2, idea3];
    this.persist();
  }
}

export const OKR_STORE: OkrStore = new OkrStore();
