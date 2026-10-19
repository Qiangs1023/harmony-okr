import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  OkrIdeaItem,
  OkrKrItem,
  OkrObjectiveItem,
  OkrParsedText,
  OkrProjectItem,
  OkrReviewItem,
  OkrSnapshot,
  OkrTagItem,
  okrDay,
  okrHashTag,
  okrNewId,
  okrNow,
  okrParseTags,
  okrStringIncludes
} from '../model/OkrModel';import {
  OkrFlowState,
  okrExpectedPercent,
  okrFlowState,
  okrIdleDays
} from '../model/OkrAnalytics';
import {
  ApiIdeaItem,
  ApiKrItem,
  ApiObjectiveItem,
  ApiProjectItem,
  ApiPushBody,
  ApiPullResult,
  ApiRemoved,
  ApiReviewItem,
  ApiTagItem
} from '../net/ApiClient';

const DOMAIN: number = 0x0A01;
const PREF_NAME: string = 'okr_store_v1';
const KEY_SNAPSHOT: string = 'snapshot';

type PersistListener = () => void;

let persistListener: PersistListener = (): void => {
};

export function setPersistListener(listener: PersistListener): void {
  persistListener = listener;
}

@ObservedV2
export class OkrStore {
  @Trace ideas: OkrIdeaItem[] = [];
  @Trace krs: OkrKrItem[] = [];
  @Trace objectives: OkrObjectiveItem[] = [];
  @Trace tags: OkrTagItem[] = [];
  @Trace projects: OkrProjectItem[] = [];
  @Trace reviews: OkrReviewItem[] = [];
  @Trace activeTag: string = '';
  @Trace showDone: boolean = true;

  private pref: preferences.Preferences | undefined = undefined;
  private removedIdeas: string[] = [];
  private removedKrs: string[] = [];
  private removedObjectives: string[] = [];
  private removedProjects: string[] = [];
  private removedTags: string[] = [];
  private removedReviews: string[] = [];
  private suppressPush: boolean = false;

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


  // ---------- 周记 ----------

  findReview(id: string): OkrReviewItem | undefined {
    for (let i = 0; i < this.reviews.length; i++) {
      if (this.reviews[i].id === id) {
        return this.reviews[i];
      }
    }
    return undefined;
  }

  /** 某目标下的周记，按周倒序 */
  reviewsOf(objectiveId: string): OkrReviewItem[] {
    const list: OkrReviewItem[] = this.reviews.filter((item: OkrReviewItem): boolean => {
      return item.objectiveId === objectiveId;
    });
    return list.sort((a: OkrReviewItem, b: OkrReviewItem): number => {
      if (a.weekKey !== b.weekKey) {
        return a.weekKey < b.weekKey ? 1 : -1;
      }
      return b.updatedAt - a.updatedAt;
    });
  }

  reviewOfWeek(objectiveId: string, weekKey: string): OkrReviewItem | undefined {
    for (let i = 0; i < this.reviews.length; i++) {
      if (this.reviews[i].objectiveId === objectiveId && this.reviews[i].weekKey === weekKey) {
        return this.reviews[i];
      }
    }
    return undefined;
  }

  /** 同一目标同一周只保留一条，写入即覆盖 */
  saveReview(objectiveId: string, weekKey: string, text: string): void {
    const body: string = text.trim();
    const existing: OkrReviewItem | undefined = this.reviewOfWeek(objectiveId, weekKey);
    if (body.length === 0) {
      if (existing !== undefined) {
        this.deleteReview(existing.id);
      }
      return;
    }
    const now: number = okrNow();
    if (existing !== undefined) {
      const next: OkrReviewItem[] = [];
      for (let i = 0; i < this.reviews.length; i++) {
        if (this.reviews[i].id === existing.id) {
          next.push({
            id: existing.id,
            objectiveId: objectiveId,
            weekKey: weekKey,
            text: body,
            createdAt: existing.createdAt,
            updatedAt: now
          });
        } else {
          next.push(this.reviews[i]);
        }
      }
      this.reviews = next;
      this.persist();
      return;
    }
    this.reviews = this.reviews.concat([{
      id: okrNewId('rv'),
      objectiveId: objectiveId,
      weekKey: weekKey,
      text: body,
      createdAt: now,
      updatedAt: now
    }]);
    this.persist();
  }

  deleteReview(id: string): void {
    const next: OkrReviewItem[] = [];
    for (let i = 0; i < this.reviews.length; i++) {
      if (this.reviews[i].id !== id) {
        next.push(this.reviews[i]);
      }
    }
    this.reviews = next;
    this.removedReviews.push(id);
    this.persist();
  }

  // ---------- 进度分析 ----------

  /** 目标的有效起止：没填就用创建日到季度末 */
  objectiveStart(objectiveId: string): number {
    const objective: OkrObjectiveItem | undefined = this.findObjective(objectiveId);
    if (objective === undefined) {
      return 0;
    }
    if (objective.startDate > 0) {
      return objective.startDate;
    }
    return objective.createdAt > 0 ? objective.createdAt : 0;
  }

  objectiveEnd(objectiveId: string): number {
    const objective: OkrObjectiveItem | undefined = this.findObjective(objectiveId);
    if (objective === undefined) {
      return 0;
    }
    if (objective.endDate > 0) {
      return objective.endDate;
    }
    return objective.createdAt > 0 ? objective.createdAt : 0;
  }

  /** KR 的应达百分比：继承所属目标的节奏，缺失时回退到 KR 自身截止日 */
  krExpected(krId: string): number {
    const kr: OkrKrItem | undefined = this.findKr(krId);
    if (kr === undefined) {
      return -1;
    }
    const start: number = this.objectiveStart(kr.objectiveId);
    let end: number = this.objectiveEnd(kr.objectiveId);
    if (start <= 0) {
      return kr.dueDate > 0
        ? okrExpectedPercent(kr.createdAt, kr.dueDate, okrNow()) : -1;
    }
    if (end <= start && kr.dueDate > start) {
      end = kr.dueDate;
    }
    return okrExpectedPercent(start, end, okrNow());
  }

  /** KR 最近一次有人动它的时间（KR 本身或它下面的任务） */
  krLastTouch(krId: string): number {
    const kr: OkrKrItem | undefined = this.findKr(krId);
    let stamp: number = kr === undefined ? 0 : kr.updatedAt;
    const linked: OkrIdeaItem[] = this.ideasOfKr(krId);
    for (let i = 0; i < linked.length; i++) {
      if (linked[i].updatedAt > stamp) {
        stamp = linked[i].updatedAt;
      }
    }
    return stamp;
  }

  krState(krId: string): OkrFlowState {
    const actual: number = this.krProgress(krId);
    const expected: number = this.krExpected(krId);
    return okrFlowState(actual, expected, okrIdleDays(this.krLastTouch(krId), okrNow()));
  }

  objectiveState(objectiveId: string): OkrFlowState {
    const list: OkrKrItem[] = this.krsOfObjective(objectiveId);
    if (list.length === 0) {
      return OkrFlowState.OnTrack;
    }
    let worst: OkrFlowState = OkrFlowState.OnTrack;
    for (let i = 0; i < list.length; i++) {
      const state: OkrFlowState = this.krState(list[i].id);
      if (state === OkrFlowState.Behind) {
        return OkrFlowState.Behind;
      }
      if (state === OkrFlowState.Stalled) {
        worst = OkrFlowState.Stalled;
      }
    }
    return worst;
  }

  /** 全部 KR 的平均实际进度 */
  overallProgress(): number {
    if (this.krs.length === 0) {
      return 0;
    }
    let sum: number = 0;
    for (let i = 0; i < this.krs.length; i++) {
      sum += this.krProgress(this.krs[i].id);
    }
    return Math.round(sum / this.krs.length);
  }

  /** 全部 KR 的平均应达进度，没有节奏时返回 -1 */
  overallExpected(): number {
    let sum: number = 0;
    let counted: number = 0;
    for (let i = 0; i < this.krs.length; i++) {
      const expected: number = this.krExpected(this.krs[i].id);
      if (expected >= 0) {
        sum += expected;
        counted++;
      }
    }
    return counted === 0 ? -1 : Math.round(sum / counted);
  }

  /** 正在进行中的目标，按截止日升序 */
  activeObjectives(): OkrObjectiveItem[] {
    const today: number = okrDay(0);
    const list: OkrObjectiveItem[] = this.objectives.filter((item: OkrObjectiveItem): boolean => {
      return this.objectiveEnd(item.id) <= 0 || this.objectiveEnd(item.id) >= today;
    });
    if (list.length === 0) {
      return this.objectives.slice();
    }
    return list.sort((a: OkrObjectiveItem, b: OkrObjectiveItem): number => {
      return this.objectiveEnd(a.id) - this.objectiveEnd(b.id);
    });
  }

  currentObjective(): OkrObjectiveItem | undefined {
    const list: OkrObjectiveItem[] = this.activeObjectives();
    return list.length === 0 ? undefined : list[0];
  }

  /** 已结束的目标里最近一个，用于「上次结算」 */
  settledObjective(): OkrObjectiveItem | undefined {
    const today: number = okrDay(0);
    let winner: OkrObjectiveItem | undefined = undefined;
    let bestEnd: number = 0;
    for (let i = 0; i < this.objectives.length; i++) {
      const end: number = this.objectiveEnd(this.objectives[i].id);
      if (end > 0 && end < today && end > bestEnd) {
        bestEnd = end;
        winner = this.objectives[i];
      }
    }
    return winner;
  }

  /** 连续记录天数：从今天（或昨天）往回数有活动的天数 */
  streakDays(): number {
    const day: number = 86400000;
    let cursor: number = okrDay(0);
    let streak: number = 0;
    let grace: boolean = true;
    for (let step: number = 0; step < 400; step++) {
      if (this.hasActivityOn(cursor)) {
        streak++;
        cursor = cursor - day;
        grace = false;
        continue;
      }
      if (grace) {
        // 今天还没记录不算断，从昨天继续数
        cursor = cursor - day;
        grace = false;
        continue;
      }
      break;
    }
    return streak;
  }

  /** 本周（周一起）有记录的天数 */
  weekActiveDays(): number {
    const day: number = 86400000;
    const today: number = okrDay(0);
    const weekday: number = new Date(today).getDay();
    const mondayOffset: number = weekday === 0 ? 6 : weekday - 1;
    let count: number = 0;
    for (let i = 0; i < 7; i++) {
      if (this.hasActivityOn(today - mondayOffset * day + i * day)) {
        count++;
      }
    }
    return count;
  }

  longestStreak(): number {
    const day: number = 86400000;
    let best: number = 0;
    let run: number = 0;
    let cursor: number = okrDay(0);
    for (let step: number = 0; step < 400; step++) {
      if (this.hasActivityOn(cursor)) {
        run++;
        if (run > best) {
          best = run;
        }
        cursor = cursor - day;
      } else {
        run = 0;
        cursor = cursor - day;
      }
    }
    return best;
  }

  private hasActivityOn(dayStart: number): boolean {
    for (let i = 0; i < this.ideas.length; i++) {
      const item: OkrIdeaItem = this.ideas[i];
      if (item.createdAt >= dayStart && item.createdAt < dayStart + 86400000) {
        return true;
      }
      if (item.updatedAt >= dayStart && item.updatedAt < dayStart + 86400000) {
        return true;
      }
    }
    return this.reviews.some((item: OkrReviewItem): boolean => {
      return item.updatedAt >= dayStart && item.updatedAt < dayStart + 86400000;
    });
  }

  /** 今日任务：今天到期或已逾期的任务，未完成排前面 */
  todayTasks(): OkrIdeaItem[] {
    const dayStart: number = okrDay(0);
    const dayEnd: number = dayStart + 86400000;
    const list: OkrIdeaItem[] = this.ideas.filter((item: OkrIdeaItem): boolean => {
      if (item.dueDate <= 0) {
        return false;
      }
      return item.dueDate < dayEnd;
    });
    return list.sort((a: OkrIdeaItem, b: OkrIdeaItem): number => {
      if (a.done !== b.done) {
        return a.done ? 1 : -1;
      }
      if (a.dueDate !== b.dueDate) {
        return a.dueDate - b.dueDate;
      }
      if (a.priority !== b.priority) {
        return b.priority - a.priority;
      }
      return b.createdAt - a.createdAt;
    });
  }

  // ---------- 想法 ----------

  addIdea(text: string, priority: number, dueDate: number, projectId: string = ''): OkrIdeaItem {
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
      projectId: projectId,
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
          projectId: idea.projectId,
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
        const copy: OkrIdeaItem = this.cloneIdea(source);
        copy.done = !source.done;
        next.push(copy);
      } else {
        next.push(source);
      }
    }
    this.ideas = next;
    this.persist();
  }

  deleteIdea(id: string): void {
    this.ideas = this.ideas.filter((item: OkrIdeaItem): boolean => item.id !== id);
    this.removedIdeas.push(id);
    this.persist();
  }

  linkIdeaToKr(ideaId: string, krId: string): void {
    this.mutateIdea(ideaId, (source: OkrIdeaItem): OkrIdeaItem => {
      const copy: OkrIdeaItem = this.cloneIdea(source);
      copy.krId = krId;
      copy.updatedAt = okrNow();
      return copy;
    });
  }

  linkIdeaToProject(ideaId: string, projectId: string): void {
    this.mutateIdea(ideaId, (source: OkrIdeaItem): OkrIdeaItem => {
      const copy: OkrIdeaItem = this.cloneIdea(source);
      copy.projectId = projectId;
      copy.updatedAt = okrNow();
      return copy;
    });
  }

  private mutateIdea(ideaId: string, mutator: (source: OkrIdeaItem) => OkrIdeaItem): void {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      next.push(source.id === ideaId ? mutator(source) : source);
    }
    this.ideas = next;
    this.persist();
  }

  private cloneIdea(source: OkrIdeaItem): OkrIdeaItem {
    return {
      id: source.id,
      title: source.title,
      note: source.note,
      tags: source.tags,
      priority: source.priority,
      dueDate: source.dueDate,
      krId: source.krId,
      projectId: source.projectId,
      done: source.done,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt
    };
  }

  // ---------- 目标与 KR ----------

  addObjective(title: string, period: string, desc: string, projectId: string = ''): OkrObjectiveItem {
    const now: number = okrNow();
    const item: OkrObjectiveItem = {
      id: okrNewId('obj'),
      title: title,
      period: period,
      startDate: 0,
      endDate: 0,
      desc: desc,
      projectId: projectId,
      createdAt: now,
      updatedAt: now
    };
    this.objectives = [item].concat(this.objectives);
    this.persist();
    return item;
  }

  /** 带起止时间新建目标：应达线依赖这个跨度 */
  addObjectiveWithSpan(title: string, desc: string, startDate: number, endDate: number,
    projectId: string = ''): OkrObjectiveItem {
    const item: OkrObjectiveItem = this.addObjective(title, '', desc, projectId);
    const next: OkrObjectiveItem[] = [];
    for (let i = 0; i < this.objectives.length; i++) {
      if (this.objectives[i].id === item.id) {
        next.push({
          id: item.id,
          title: item.title,
          period: item.period,
          startDate: startDate > 0 ? startDate : okrDay(0),
          endDate: endDate > startDate ? endDate : okrDay(0) + 89 * 86400000,
          desc: item.desc,
          projectId: projectId,
          createdAt: item.createdAt,
          updatedAt: okrNow()
        });
      } else {
        next.push(this.objectives[i]);
      }
    }
    this.objectives = next;
    this.persist();
    return item;
  }

  addKr(objectiveId: string, title: string, targetValue: string, dueDate: number): OkrKrItem {
    const now: number = okrNow();
    const item: OkrKrItem = {
      id: okrNewId('kr'),
      objectiveId: objectiveId,
      title: title,
      targetValue: targetValue,
      dueDate: dueDate,
      projectId: '',
      createdAt: now,
      updatedAt: now
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
          projectId: kr.projectId,
          createdAt: kr.createdAt,
          updatedAt: okrNow()
        });
      } else {
        next.push(this.krs[i]);
      }
    }
    this.krs = next;
    this.persist();
  }

  updateObjective(objective: OkrObjectiveItem): void {
    const next: OkrObjectiveItem[] = [];
    for (let i = 0; i < this.objectives.length; i++) {
      if (this.objectives[i].id === objective.id) {
        next.push({
          id: objective.id,
          startDate: objective.startDate,
          endDate: objective.endDate,
          title: objective.title,
          period: objective.period,
          desc: objective.desc,
          projectId: objective.projectId,
          createdAt: objective.createdAt,
          updatedAt: okrNow()
        });
      } else {
        next.push(this.objectives[i]);
      }
    }
    this.objectives = next;
    this.persist();
  }

  linkObjectiveToProject(objectiveId: string, projectId: string): void {
    const found: OkrObjectiveItem | undefined = this.findObjective(objectiveId);
    if (found === undefined) {
      return;
    }
    const draft: OkrObjectiveItem = {
      id: found.id,
      title: found.title,
      period: found.period,
      startDate: found.startDate,
      endDate: found.endDate,
      desc: found.desc,
      projectId: projectId,
      createdAt: found.createdAt,
      updatedAt: found.updatedAt
    };
    this.updateObjective(draft);
  }

  deleteKr(krId: string): void {
    this.krs = this.krs.filter((item: OkrKrItem): boolean => item.id !== krId);
    this.removedKrs.push(krId);
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
    this.removedObjectives.push(objectiveId);
    this.persist();
  }

  private unlinkKr(krId: string): void {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      if (source.krId === krId) {
        next.push(this.cloneIdea(source));
      } else {
        next.push(source);
      }
    }
    this.ideas = next;
  }

  // ---------- 项目 ----------

  findProject(id: string): OkrProjectItem | undefined {
    for (let i = 0; i < this.projects.length; i++) {
      if (this.projects[i].id === id) {
        return this.projects[i];
      }
    }
    return undefined;
  }

  projectList(showArchived: boolean): OkrProjectItem[] {
    if (showArchived) {
      return this.projects.slice();
    }
    return this.projects.filter((item: OkrProjectItem): boolean => !item.archived);
  }

  projectTitle(projectId: string): string {
    const found: OkrProjectItem | undefined = this.findProject(projectId);
    return found === undefined ? '' : found.title;
  }

  ideasOfProject(projectId: string): OkrIdeaItem[] {
    return this.ideas.filter((item: OkrIdeaItem): boolean => item.projectId === projectId);
  }

  krsOfProject(projectId: string): OkrKrItem[] {
    return this.krs.filter((item: OkrKrItem): boolean => item.projectId === projectId);
  }

  objectivesOfProject(projectId: string): OkrObjectiveItem[] {
    return this.objectives.filter((item: OkrObjectiveItem): boolean => item.projectId === projectId);
  }

  projectProgress(projectId: string): number {
    const list: OkrIdeaItem[] = this.ideasOfProject(projectId);
    if (list.length === 0) {
      return 0;
    }
    let doneCount: number = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].done) {
        doneCount++;
      }
    }
    return Math.round((doneCount / list.length) * 100);
  }

  /** 项目下 KR 的平均应达进度 */
  projectExpected(projectId: string): number {
    const list: OkrKrItem[] = this.krsOfProject(projectId);
    let sum: number = 0;
    let counted: number = 0;
    for (let i = 0; i < list.length; i++) {
      const expected: number = this.krExpected(list[i].id);
      if (expected >= 0) {
        sum = sum + expected;
        counted++;
      }
    }
    return counted === 0 ? -1 : Math.round(sum / counted);
  }

  addProject(title: string, desc: string, colorIndex: number): OkrProjectItem {
    const now: number = okrNow();
    const item: OkrProjectItem = {
      id: okrNewId('proj'),
      title: title,
      desc: desc,
      colorIndex: colorIndex,
      archived: false,
      createdAt: now,
      updatedAt: now
    };
    this.projects = [item].concat(this.projects);
    this.persist();
    return item;
  }

  updateProject(project: OkrProjectItem): void {
    const next: OkrProjectItem[] = [];
    for (let i = 0; i < this.projects.length; i++) {
      if (this.projects[i].id === project.id) {
        next.push({
          id: project.id,
          title: project.title,
          desc: project.desc,
          colorIndex: project.colorIndex,
          archived: project.archived,
          createdAt: project.createdAt,
          updatedAt: okrNow()
        });
      } else {
        next.push(this.projects[i]);
      }
    }
    this.projects = next;
    this.persist();
  }

  setProjectArchived(projectId: string, archived: boolean): void {
    const found: OkrProjectItem | undefined = this.findProject(projectId);
    if (found === undefined) {
      return;
    }
    const draft: OkrProjectItem = {
      id: found.id,
      title: found.title,
      desc: found.desc,
      colorIndex: found.colorIndex,
      archived: archived,
      createdAt: found.createdAt,
      updatedAt: found.updatedAt
    };
    this.updateProject(draft);
  }

  deleteProject(projectId: string): void {
    this.projects = this.projects.filter((item: OkrProjectItem): boolean => item.id !== projectId);
    this.removedProjects.push(projectId);
    for (let i = 0; i < this.krs.length; i++) {
      if (this.krs[i].projectId === projectId) {
        const draft: OkrKrItem = this.cloneKr(this.krs[i]);
        draft.projectId = '';
        this.updateKr(draft);
      }
    }
    for (let i = 0; i < this.objectives.length; i++) {
      if (this.objectives[i].projectId === projectId) {
        this.linkObjectiveToProject(this.objectives[i].id, '');
      }
    }
    const ideas: OkrIdeaItem[] = this.ideasOfProject(projectId);
    for (let i = 0; i < ideas.length; i++) {
      this.linkIdeaToProject(ideas[i].id, '');
    }
    this.persist();
  }

  private cloneKr(source: OkrKrItem): OkrKrItem {
    return {
      id: source.id,
      objectiveId: source.objectiveId,
      title: source.title,
      targetValue: source.targetValue,
      dueDate: source.dueDate,
      projectId: source.projectId,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt
    };
  }

  // ---------- 标签管理 ----------

  createTag(name: string, colorIndex: number): void {
    const trimmed: string = name.trim();
    if (trimmed.length === 0 || this.hasTag(trimmed)) {
      return;
    }
    this.tags = this.tags.concat([{
      name: trimmed,
      colorIndex: colorIndex,
      sortIndex: this.tags.length
    }]);
    this.persist();
  }

  moveTag(from: number, to: number): void {
    const size: number = this.tags.length;
    if (from < 0 || from >= size || to < 0 || to >= size || from === to) {
      return;
    }
    const next: OkrTagItem[] = this.tags.slice();
    const moved: OkrTagItem = next[from];
    next.splice(from, 1);
    next.splice(to, 0, moved);
    this.tags = next;
    this.persist();
  }

  hasTag(name: string): boolean {
    for (let i = 0; i < this.tags.length; i++) {
      if (this.tags[i].name === name) {
        return true;
      }
    }
    return false;
  }

  renameTag(oldName: string, newName: string): void {
    const trimmed: string = newName.trim();
    if (trimmed.length === 0 || oldName === trimmed || this.hasTag(trimmed)) {
      return;
    }
    const tags: OkrTagItem[] = [];
    for (let i = 0; i < this.tags.length; i++) {
      tags.push(this.tags[i].name === oldName
        ? { name: trimmed, colorIndex: this.tags[i].colorIndex, sortIndex: this.tags[i].sortIndex }
        : this.tags[i]);
    }
    this.tags = tags;
    const ideas: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      if (okrStringIncludes(source.tags, oldName)) {
        const copy: OkrIdeaItem = this.cloneIdea(source);
        const nextTags: string[] = [];
        for (let j = 0; j < copy.tags.length; j++) {
          nextTags.push(copy.tags[j] === oldName ? trimmed : copy.tags[j]);
        }
        copy.tags = nextTags;
        copy.updatedAt = okrNow();
        ideas.push(copy);
      } else {
        ideas.push(source);
      }
    }
    this.ideas = ideas;
    if (this.activeTag === oldName) {
      this.activeTag = trimmed;
    }
    this.persist();
  }

  setTagColor(name: string, colorIndex: number): void {
    const tags: OkrTagItem[] = [];
    for (let i = 0; i < this.tags.length; i++) {
      tags.push(this.tags[i].name === name
        ? { name: this.tags[i].name, colorIndex: colorIndex, sortIndex: this.tags[i].sortIndex }
        : this.tags[i]);
    }
    this.tags = tags;
    this.persist();
  }

  deleteTag(name: string): void {
    this.tags = this.tags.filter((item: OkrTagItem): boolean => item.name !== name);
    this.removedTags.push(name);
    const ideas: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      if (okrStringIncludes(source.tags, name)) {
        const copy: OkrIdeaItem = this.cloneIdea(source);
        const nextTags: string[] = [];
        for (let j = 0; j < copy.tags.length; j++) {
          if (copy.tags[j] !== name) {
            nextTags.push(copy.tags[j]);
          }
        }
        copy.tags = nextTags;
        copy.updatedAt = okrNow();
        ideas.push(copy);
      } else {
        ideas.push(source);
      }
    }
    this.ideas = ideas;
    if (this.activeTag === name) {
      this.activeTag = '';
    }
    this.persist();
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
        const tag: OkrTagItem = { name: name, colorIndex: okrHashTag(name), sortIndex: next.length };
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
      if (data.projects !== undefined && data.projects !== null) {
        this.projects = data.projects;
      }
      if (data.reviews !== undefined && data.reviews !== null) {
        this.reviews = data.reviews;
      }
      this.normalize();
    } catch (err) {
      hilog.error(DOMAIN, 'OkrStore', 'parse failed: %{public}s', JSON.stringify(err));
    }
  }

  private normalize(): void {
    const normalizedTags: OkrTagItem[] = [];
    for (let i = 0; i < this.tags.length; i++) {
      normalizedTags.push({
        name: this.tags[i].name,
        colorIndex: this.tags[i].colorIndex,
        sortIndex: typeof this.tags[i].sortIndex === 'number' ? this.tags[i].sortIndex : i
      });
    }
    this.tags = normalizedTags;

    const krs: OkrKrItem[] = [];
    for (let i = 0; i < this.krs.length; i++) {
      const source: OkrKrItem = this.krs[i];
      const stamp: number = typeof source.updatedAt === 'number' && source.updatedAt > 0
        ? source.updatedAt : source.createdAt;
      krs.push({
        id: source.id,
        objectiveId: source.objectiveId,
        title: source.title,
        targetValue: source.targetValue,
        dueDate: source.dueDate,
        projectId: typeof source.projectId === 'string' ? source.projectId : '',
        createdAt: source.createdAt,
        updatedAt: stamp
      });
    }
    this.krs = krs;

    const objectives: OkrObjectiveItem[] = [];
    for (let i = 0; i < this.objectives.length; i++) {
      const source: OkrObjectiveItem = this.objectives[i];
      const stamp: number = typeof source.updatedAt === 'number' && source.updatedAt > 0
        ? source.updatedAt : source.createdAt;
      objectives.push({
        id: source.id,
        startDate: typeof source.startDate === 'number' ? source.startDate : 0,
        endDate: typeof source.endDate === 'number' ? source.endDate : 0,
        title: source.title,
        period: source.period,
        desc: source.desc,
        projectId: typeof source.projectId === 'string' ? source.projectId : '',
        createdAt: source.createdAt,
        updatedAt: stamp
      });
    }
    this.objectives = objectives;

    const ideas: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const source: OkrIdeaItem = this.ideas[i];
      const copy: OkrIdeaItem = this.cloneIdea(source);
      copy.projectId = typeof source.projectId === 'string' ? source.projectId : '';
      ideas.push(copy);
    }
    this.ideas = ideas;

    const projects: OkrProjectItem[] = [];
    for (let i = 0; i < this.projects.length; i++) {
      const source: OkrProjectItem = this.projects[i];
      const stamp: number = typeof source.updatedAt === 'number' && source.updatedAt > 0
        ? source.updatedAt : source.createdAt;
      projects.push({
        id: source.id,
        title: source.title,
        desc: typeof source.desc === 'string' ? source.desc : '',
        colorIndex: typeof source.colorIndex === 'number' ? source.colorIndex : okrHashTag(source.title),
        archived: source.archived === true,
        createdAt: source.createdAt,
        updatedAt: stamp
      });
    }
    this.projects = projects;

    const reviews: OkrReviewItem[] = [];
    for (let i = 0; i < this.reviews.length; i++) {
      const source: OkrReviewItem = this.reviews[i];
      if (source === null || source === undefined || typeof source.id !== 'string') {
        continue;
      }
      const stamp: number = typeof source.updatedAt === 'number' && source.updatedAt > 0
        ? source.updatedAt : source.createdAt;
      reviews.push({
        id: source.id,
        objectiveId: typeof source.objectiveId === 'string' ? source.objectiveId : '',
        weekKey: typeof source.weekKey === 'string' ? source.weekKey : '',
        text: typeof source.text === 'string' ? source.text : '',
        createdAt: source.createdAt,
        updatedAt: stamp
      });
    }
    this.reviews = reviews;
  }

  private persist(): void {
    const snapshot: OkrSnapshot = {
      ideas: this.ideas,
      krs: this.krs,
      objectives: this.objectives,
      tags: this.tags,
      projects: this.projects,
      reviews: this.reviews
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
    if (!this.suppressPush) {
      persistListener();
    }
  }

  // ---------- 云同步 ----------

  buildPushBody(deviceId: string): ApiPushBody {
    const objectives: ApiObjectiveItem[] = [];
    for (let i = 0; i < this.objectives.length; i++) {
      const item: OkrObjectiveItem = this.objectives[i];
      objectives.push({
        id: item.id,
        startDate: item.startDate,
        endDate: item.endDate,
        title: item.title,
        period: item.period,
        note: item.desc,
        projectId: item.projectId,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      });
    }
    const krs: ApiKrItem[] = [];
    for (let i = 0; i < this.krs.length; i++) {
      const item: OkrKrItem = this.krs[i];
      krs.push({
        id: item.id,
        objectiveId: item.objectiveId,
        title: item.title,
        targetValue: item.targetValue,
        dueDate: item.dueDate,
        projectId: item.projectId,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      });
    }
    const ideas: ApiIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      const item: OkrIdeaItem = this.ideas[i];
      ideas.push({
        id: item.id,
        title: item.title,
        note: item.note,
        tags: item.tags,
        priority: item.priority,
        dueDate: item.dueDate,
        krId: item.krId,
        projectId: item.projectId,
        done: item.done,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      });
    }
    const tags: ApiTagItem[] = [];
    for (let i = 0; i < this.tags.length; i++) {
      // 数组顺序即展示顺序，sortIndex 一律按当前下标重算，避免拖拽后残留旧值
      tags.push({
        name: this.tags[i].name,
        colorIndex: this.tags[i].colorIndex,
        sortIndex: i
      });
    }
    const projects: ApiProjectItem[] = [];
    for (let i = 0; i < this.projects.length; i++) {
      const item: OkrProjectItem = this.projects[i];
      projects.push({
        id: item.id,
        title: item.title,
        note: item.desc,
        colorIndex: item.colorIndex,
        archived: item.archived,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      });
    }
    const reviews: ApiReviewItem[] = [];
    for (let i = 0; i < this.reviews.length; i++) {
      const item: OkrReviewItem = this.reviews[i];
      reviews.push({
        id: item.id,
        objectiveId: item.objectiveId,
        weekKey: item.weekKey,
        text: item.text,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      });
    }
    const removed: ApiRemoved = {
      objectives: this.removedObjectives.slice(),
      krs: this.removedKrs.slice(),
      ideas: this.removedIdeas.slice(),
      tags: this.removedTags.slice(),
      projects: this.removedProjects.slice(),
      reviews: this.removedReviews.slice()
    };
    return {
      deviceId: deviceId,
      objectives: objectives,
      krs: krs,
      ideas: ideas,
      tags: tags,
      projects: projects,
      reviews: reviews,
      removed: removed
    };
  }

  clearRemoved(): void {
    this.removedIdeas = [];
    this.removedKrs = [];
    this.removedObjectives = [];
    this.removedProjects = [];
    this.removedTags = [];
    this.removedReviews = [];
  }

  applyRemote(remote: ApiPullResult): boolean {
    this.suppressPush = true;
    let changed: boolean = false;

    for (let i = 0; i < remote.objectives.length; i++) {
      const incoming: ApiObjectiveItem = remote.objectives[i];
      const local: OkrObjectiveItem | undefined = this.findObjective(incoming.id);
      if (local === undefined) {
        this.objectives = this.objectives.concat([{
          id: incoming.id,
          startDate: incoming.startDate,
          endDate: incoming.endDate,
          title: incoming.title,
          period: incoming.period,
          desc: incoming.note,
          projectId: incoming.projectId,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        }]);
        changed = true;
      } else if (incoming.updatedAt > local.updatedAt) {
        this.objectives = this.replaceObjective(local, incoming);
        changed = true;
      }
    }

    for (let i = 0; i < remote.krs.length; i++) {
      const incoming: ApiKrItem = remote.krs[i];
      const local: OkrKrItem | undefined = this.findKr(incoming.id);
      if (local === undefined) {
        this.krs = this.krs.concat([{
          id: incoming.id,
          objectiveId: incoming.objectiveId,
          title: incoming.title,
          targetValue: incoming.targetValue,
          dueDate: incoming.dueDate,
          projectId: incoming.projectId,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        }]);
        changed = true;
      } else if (incoming.updatedAt > local.updatedAt) {
        this.krs = this.replaceKr(local, incoming);
        changed = true;
      }
    }

    for (let i = 0; i < remote.ideas.length; i++) {
      const incoming: ApiIdeaItem = remote.ideas[i];
      const local: OkrIdeaItem | undefined = this.findIdea(incoming.id);
      if (local === undefined) {
        this.ideas = this.ideas.concat([{
          id: incoming.id,
          title: incoming.title,
          note: incoming.note,
          tags: incoming.tags,
          priority: incoming.priority,
          dueDate: incoming.dueDate,
          krId: incoming.krId,
          projectId: incoming.projectId,
          done: incoming.done,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        }]);
        changed = true;
      } else if (incoming.updatedAt > local.updatedAt) {
        this.ideas = this.replaceIdea(local, incoming);
        changed = true;
      }
    }

    for (let i = 0; i < remote.projects.length; i++) {
      const incoming: ApiProjectItem = remote.projects[i];
      const local: OkrProjectItem | undefined = this.findProject(incoming.id);
      if (local === undefined) {
        this.projects = this.projects.concat([{
          id: incoming.id,
          title: incoming.title,
          desc: incoming.note,
          colorIndex: incoming.colorIndex,
          archived: incoming.archived,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        }]);
        changed = true;
      } else if (incoming.updatedAt > local.updatedAt) {
        this.projects = this.replaceProject(local, incoming);
        changed = true;
      }
    }

    for (let i = 0; i < remote.tags.length; i++) {
      const incoming: ApiTagItem = remote.tags[i];
      let exists: boolean = false;
      for (let j = 0; j < this.tags.length; j++) {
        if (this.tags[j].name === incoming.name) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        this.tags = this.tags.concat([{
          name: incoming.name,
          colorIndex: incoming.colorIndex,
          sortIndex: incoming.sortIndex
        }]);
        changed = true;
      }
    }

    for (let i = 0; i < remote.reviews.length; i++) {
      const incoming: ApiReviewItem = remote.reviews[i];
      if (this.findReview(incoming.id) === undefined) {
        this.reviews = this.reviews.concat([{
          id: incoming.id,
          objectiveId: incoming.objectiveId,
          weekKey: incoming.weekKey,
          text: incoming.text,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        }]);
        changed = true;
        continue;
      }
      const next: OkrReviewItem[] = [];
      let touched: boolean = false;
      for (let j = 0; j < this.reviews.length; j++) {
        if (this.reviews[j].id !== incoming.id) {
          next.push(this.reviews[j]);
          continue;
        }
        if (incoming.updatedAt > this.reviews[j].updatedAt) {
          next.push({
            id: incoming.id,
            objectiveId: incoming.objectiveId,
            weekKey: incoming.weekKey,
            text: incoming.text,
            createdAt: incoming.createdAt,
            updatedAt: incoming.updatedAt
          });
          touched = true;
        } else {
          next.push(this.reviews[j]);
        }
      }
      if (touched) {
        this.reviews = next;
        changed = true;
      }
    }

    this.suppressPush = false;
    if (changed) {
      this.persistLocal();
    }
    return changed;
  }

  private persistLocal(): void {
    const snapshot: OkrSnapshot = {
      ideas: this.ideas,
      krs: this.krs,
      objectives: this.objectives,
      tags: this.tags,
      projects: this.projects,
      reviews: this.reviews
    };
    if (this.pref === undefined) {
      return;
    }
    this.pref.put(KEY_SNAPSHOT, JSON.stringify(snapshot)).then(() => {
      this.pref?.flush();
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'OkrStore', 'save failed: %{public}s', err.message);
    });
  }

  private replaceObjective(local: OkrObjectiveItem, incoming: ApiObjectiveItem): OkrObjectiveItem[] {
    const next: OkrObjectiveItem[] = [];
    for (let i = 0; i < this.objectives.length; i++) {
      if (this.objectives[i].id === local.id) {
        next.push({
          id: incoming.id,
          startDate: incoming.startDate,
          endDate: incoming.endDate,
          title: incoming.title,
          period: incoming.period,
          desc: incoming.note,
          projectId: incoming.projectId,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        });
      } else {
        next.push(this.objectives[i]);
      }
    }
    return next;
  }

  private replaceKr(local: OkrKrItem, incoming: ApiKrItem): OkrKrItem[] {
    const next: OkrKrItem[] = [];
    for (let i = 0; i < this.krs.length; i++) {
      if (this.krs[i].id === local.id) {
        next.push({
          id: incoming.id,
          objectiveId: incoming.objectiveId,
          title: incoming.title,
          targetValue: incoming.targetValue,
          dueDate: incoming.dueDate,
          projectId: incoming.projectId,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        });
      } else {
        next.push(this.krs[i]);
      }
    }
    return next;
  }

  private replaceProject(local: OkrProjectItem, incoming: ApiProjectItem): OkrProjectItem[] {
    const next: OkrProjectItem[] = [];
    for (let i = 0; i < this.projects.length; i++) {
      if (this.projects[i].id === local.id) {
        next.push({
          id: incoming.id,
          title: incoming.title,
          desc: incoming.note,
          colorIndex: incoming.colorIndex,
          archived: incoming.archived,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        });
      } else {
        next.push(this.projects[i]);
      }
    }
    return next;
  }

  private replaceIdea(local: OkrIdeaItem, incoming: ApiIdeaItem): OkrIdeaItem[] {
    const next: OkrIdeaItem[] = [];
    for (let i = 0; i < this.ideas.length; i++) {
      if (this.ideas[i].id === local.id) {
        next.push({
          id: incoming.id,
          title: incoming.title,
          note: incoming.note,
          tags: incoming.tags,
          priority: incoming.priority,
          dueDate: incoming.dueDate,
          krId: incoming.krId,
          projectId: incoming.projectId,
          done: incoming.done,
          createdAt: incoming.createdAt,
          updatedAt: incoming.updatedAt
        });
      } else {
        next.push(this.ideas[i]);
      }
    }
    return next;
  }

  private seed(): void {
    const now: number = okrNow();
    const day: number = 86400000;
    const project: OkrProjectItem = {
      id: okrNewId('proj'),
      title: 'OKR 记事本',
      desc: '把日常记录做成能追踪的闭环',
      colorIndex: 4,
      archived: false,
      createdAt: now,
      updatedAt: now
    };
    const objective: OkrObjectiveItem = {
      id: okrNewId('obj'),
      title: '打造个人 OKR 闭环',
      period: '本季度',
      startDate: now,
      endDate: now + 90 * day,
      desc: '把零散灵感沉淀成可追踪的目标与关键结果',
      projectId: project.id,
      createdAt: now,
      updatedAt: now
    };
    const kr1: OkrKrItem = {
      id: okrNewId('kr'),
      objectiveId: objective.id,
      title: '上线 OKR 记录 App 并坚持使用',
      targetValue: '连续记录 30 天',
      dueDate: now + 30 * day,
      projectId: project.id,
      createdAt: now,
      updatedAt: now
    };
    const kr2: OkrKrItem = {
      id: okrNewId('kr'),
      objectiveId: objective.id,
      title: '每周复盘一次关键结果进度',
      targetValue: '每周 1 次，共 12 周',
      dueDate: now + 84 * day,
      projectId: project.id,
      createdAt: now,
      updatedAt: now
    };
    this.projects = [project];
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
      projectId: project.id,
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
      projectId: project.id,
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
      projectId: project.id,
      done: true,
      createdAt: now - 2 * day,
      updatedAt: now - day
    };
    this.ideas = [idea1, idea2, idea3];
    this.persist();
  }
}

export const OKR_STORE: OkrStore = new OkrStore();
