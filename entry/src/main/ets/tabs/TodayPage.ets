import { OkrFlowState, okrFlowLabel, okrQuarterLabel, okrWeekdayLabel } from '../model/OkrAnalytics';
import { OkrIdeaItem, OkrKrItem, OkrObjectiveItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import {
  OkrCardHead,
  OkrGhostButton,
  OkrHairline,
  OkrLedgerLine,
  OkrMeter,
  OkrPageHeader,
  OkrSolidButton
} from '../components/OkrUi';

interface FocusPick {
  krId: string;
  objectiveId: string;
}

@ComponentV2
export struct TodayPage {
  @Event onOpenKr: (krId: string) => void = (_krId: string): void => {
  };
  @Event onOpenObjective: (objectiveId: string) => void = (_objectiveId: string): void => {
  };
  @Event onQuickAdd: () => void = (): void => {
  };

  private focusKr(): FocusPick | undefined {
    const tasks: OkrIdeaItem[] = OKR_STORE.todayTasks();
    const tally: number[] = [];
    const owners: string[] = [];
    for (let i = 0; i < tasks.length; i++) {
      if (tasks[i].done || tasks[i].krId.length === 0) {
        continue;
      }
      const slot: number = owners.indexOf(tasks[i].krId);
      if (slot < 0) {
        owners.push(tasks[i].krId);
        tally.push(1);
      } else {
        tally[slot] = tally[slot] + 1;
      }
    }
    let best: string = '';
    let bestCount: number = 0;
    for (let i = 0; i < owners.length; i++) {
      if (tally[i] > bestCount) {
        best = owners[i];
        bestCount = tally[i];
      }
    }
    if (best.length === 0) {
      if (OKR_STORE.krs.length === 0) {
        return undefined;
      }
      const fallback: string = OKR_STORE.krs[0].id;
      return { krId: fallback, objectiveId: OKR_STORE.krObjectiveId(fallback) };
    }
    return { krId: best, objectiveId: OKR_STORE.krObjectiveId(best) };
  }

  private focusObjective(): OkrObjectiveItem | undefined {
    const pick: FocusPick | undefined = this.focusKr();
    if (pick === undefined) {
      return OKR_STORE.currentObjective();
    }
    return OKR_STORE.findObjective(pick.objectiveId);
  }

  private eyebrowText(): string {
    const now: number = Date.now();
    const date: Date = new Date(now);
    const objective: OkrObjectiveItem | undefined = OKR_STORE.currentObjective();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    let text: string = `${month}月${day}日 · ${okrWeekdayLabel(now)}`;
    if (objective !== undefined) {
      const start: number = OKR_STORE.objectiveStart(objective.id);
      text = `${okrQuarterLabel(start)} · ${text}`;
    }
    return text;
  }

  private subText(): string {
    const todo: number = OKR_STORE.todoCount();
    if (todo === 0) {
      return '没有待办，今天可以收个尾';
    }
    return `待办 ${todo} 条 · 今天做完就算往前走`;
  }

  private focusStory(): string {
    const pick: FocusPick | undefined = this.focusKr();
    if (pick === undefined) {
      return '还没有设定关键结果，先定一个能被验证的数字。';
    }
    const actual: number = OKR_STORE.krProgress(pick.krId);
    const expected: number = OKR_STORE.krExpected(pick.krId);
    const total: number = OKR_STORE.ideasOfKr(pick.krId).length;
    const left: number = Math.max(0, total - Math.round(total * actual / 100));
    if (expected < 0) {
      return `这条 KR 还没填起止时间，按任务完成度走。还剩 ${left} 个任务。`;
    }
    const gap: number = actual - expected;
    if (gap >= 0) {
      return `你正领先应达线 ${gap}%，还剩 ${left} 个任务就能收掉。`;
    }
    return `你落后应达线 ${-gap}%，剩下 ${left} 个任务得追回来。`;
  }

  private focusLedger(): string {
    const pick: FocusPick | undefined = this.focusKr();
    if (pick === undefined) {
      return '';
    }
    const linked: OkrIdeaItem[] = OKR_STORE.ideasOfKr(pick.krId);
    let done: number = 0;
    for (let i = 0; i < linked.length; i++) {
      if (linked[i].done) {
        done++;
      }
    }
    return `${done} / ${linked.length}`;
  }

  private focusStateText(): string {
    const pick: FocusPick | undefined = this.focusKr();
    if (pick === undefined) {
      return '';
    }
    const state: OkrFlowState = OKR_STORE.krState(pick.krId);
    return okrFlowLabel(state, OKR_STORE.krProgress(pick.krId), OKR_STORE.krExpected(pick.krId));
  }

  private focusLedgerSuffix(): string {
    const pick: FocusPick | undefined = this.focusKr();
    if (pick === undefined) {
      return '';
    }
    return `${OKR_STORE.ideasOfKr(pick.krId).length} 个任务`;
  }

  @Builder
  focusCard() {
    Column({ space: 0 }) {
      Row() {
        Text('今日焦点')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(1.6)
          .fontColor($r('app.color.okr_text_tertiary'))
        Blank()
        OkrTextLink({
          label: '查看',
          onTap: (): void => {
          const pick: FocusPick | undefined = this.focusKr();
            if (pick !== undefined) {
              this.onOpenKr(pick.krId);
            }
          }
        })
      }
      .width('100%')

      Text(this.focusKr() === undefined ? '先定一个目标' : OKR_STORE.krTitle(this.focusKr()?.krId ?? ''))
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(-0.3)
        .fontColor($r('app.color.okr_text_primary'))
        .margin({ top: 12 })

      Text(this.focusStory())
        .fontSize(13)
        .fontWeight(FontWeight.Lighter)
        .lineHeight(21)
        .fontColor($r('app.color.okr_text_secondary'))
        .margin({ top: 8 })

      if (this.focusKr() !== undefined) {
        Column({ space: 12 }) {
          KrLine({ krId: this.focusKr()?.krId ?? '' })
        }
        .width('100%')
        .margin({ top: 18 })
      }

      Row({ space: 9 }) {
        OkrSolidButton({
          label: '记录进展',
          onTap: (): void => {
            this.onQuickAdd();
          }
        })
        OkrGhostButton({
          label: '看任务 →',
          onTap: (): void => {
            const pick: FocusPick | undefined = this.focusKr();
            if (pick !== undefined) {
              this.onOpenObjective(pick.objectiveId);
            }
          }
        })
      }
      .margin({ top: 18 })
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .borderWidth({ top: 2, right: 1, bottom: 1, left: 1 })
    .borderColor({
      top: $r('app.color.okr_text_primary'),
      right: $r('app.color.okr_divider'),
      bottom: $r('app.color.okr_divider'),
      left: $r('app.color.okr_divider')
    })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
  }

  @Builder
  streakCard() {
    Column({ space: 0 }) {
      Row() {
        Text('连续记录')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.okr_text_secondary'))
        Blank()
        Text(`${OKR_STORE.streakDays()}天`)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.6)
          .fontColor($r('app.color.okr_text_primary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row() {
        Row()
          .width(`${Math.min(100, OKR_STORE.streakDays() / 31 * 100)}%`)
          .height(5)
          .borderRadius(3)
          .backgroundColor($r('app.color.okr_text_primary'))
      }
      .width('100%')
      .height(5)
      .borderRadius(3)
      .backgroundColor($r('app.color.okr_track'))
      .margin({ top: 12 })

      Row() {
        Text(`本周 ${OKR_STORE.weekActiveDays()} / 7 天`)
          .fontSize(10)
          .fontColor($r('app.color.okr_text_tertiary'))
        Blank()
        Text(`最长 ${OKR_STORE.longestStreak()} 天`)
          .fontSize(10)
          .fontColor($r('app.color.okr_text_tertiary'))
      }
      .width('100%')
      .margin({ top: 9 })
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
  }

  @Builder
  taskCard() {
    Column() {
      Row() {
        OkrCardHead({
          title: '今日任务',
          hint: `${this.doneToday()} / ${this.taskTotal()}`
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 })

      OkrHairline()

      if (this.taskTotal() === 0) {
        Text('今天没有到期的任务')
          .fontSize(13)
          .fontColor($r('app.color.okr_text_tertiary'))
          .padding({ left: 18, right: 18, top: 24, bottom: 24 })
      } else {
        ForEach(OKR_STORE.todayTasks(), (item: OkrIdeaItem): void => {
          TaskRow({
            taskId: item.id,
            krTitle: OKR_STORE.krTitle(item.krId),
            krState: item.krId.length > 0 ? OKR_STORE.krState(item.krId) : OkrFlowState.OnTrack,
            onOpen: (id: string): void => {
              this.onOpenKr(id);
            }
          })
        }, (item: OkrIdeaItem): string => item.id)
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
    .clip(true)
  }

  private taskTotal(): number {
    return OKR_STORE.todayTasks().length;
  }

  private doneToday(): number {
    const list: OkrIdeaItem[] = OKR_STORE.todayTasks();
    let count: number = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].done) {
        count++;
      }
    }
    return count;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        OkrPageHeader({
          eyebrow: this.eyebrowText(),
          title: '今天',
          sub: this.subText()
        })

        this.focusCard()

        this.streakCard()

        this.taskCard()

        Column({ space: 12 }) {
          OkrCardHead({ title: '快速记录' })
          Text('一句话：刚刚发生了什么…')
            .fontSize(13.5)
            .fontColor($r('app.color.okr_ink_faint'))
            .width('100%')
            .height(26)
            .onClick((): void => {
              this.onQuickAdd();
            })
        }
        .width('100%')
        .padding(18)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.okr_card'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.okr_divider') })
        .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}

/** KR 账本块：名称 + 百分比 + 数字行 + 双层刻度条 */
@ComponentV2
export struct KrLine {
  @Param krId: string = '';

  private state(): OkrFlowState {
    return OKR_STORE.krState(this.krId);
  }

  private statsLine(): string {
    const linked: OkrIdeaItem[] = OKR_STORE.ideasOfKr(this.krId);
    let done: number = 0;
    for (let i = 0; i < linked.length; i++) {
      if (linked[i].done) {
        done++;
      }
    }
    return `${done} / ${linked.length}`;
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 10 }) {
        Text(OKR_STORE.krTitle(this.krId))
          .fontSize(14.5)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.okr_text_primary'))
        Text(`${OKR_STORE.krProgress(this.krId)}%`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.3)
          .fontColor($r('app.color.okr_text_primary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      OkrLedgerLine({
        leftText: `${this.statsLine()} · ${okrFlowLabel(this.state(), OKR_STORE.krProgress(this.krId), OKR_STORE.krExpected(this.krId))} · ${this.linkedCount()} 个任务`,
        rightText: '',
        tone: this.state()
      })

      OkrMeter({
        actual: OKR_STORE.krProgress(this.krId),
        expected: OKR_STORE.krExpected(this.krId),
        state: this.state()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private linkedCount(): number {
    return OKR_STORE.ideasOfKr(this.krId).length;
  }
}

/** 任务行：方形勾选框 + 任务文案 + 等宽小字关联 KR */
@ComponentV2
export struct TaskRow {
  @Param taskId: string = '';
  @Param krTitle: string = '';
  @Param krState: OkrFlowState = OkrFlowState.OnTrack;
  @Event onOpen: (krId: string) => void = (_krId: string): void => {
  };

  private task(): OkrIdeaItem | undefined {
    return OKR_STORE.findIdea(this.taskId);
  }

  private done(): boolean {
    const item: OkrIdeaItem | undefined = this.task();
    return item !== undefined && item.done;
  }

  private dotColor(): string {
    if (this.krState === OkrFlowState.Behind) {
      return '#C0402C';
    }
    if (this.krState === OkrFlowState.OnTrack) {
      return '#2F55D4';
    }
    return '#B9C0C6';
  }

  build() {
    Row({ space: 13 }) {
      Column() {
        if (this.done()) {
          Text('✓')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.okr_on_primary'))
        }
      }
      .width(17)
      .height(17)
      .borderRadius(5)
      .backgroundColor(this.done() ? $r('app.color.okr_primary') : $r('app.color.okr_card'))
      .border({ width: 1.5, color: this.done() ? $r('app.color.okr_primary') : $r('app.color.okr_rule_strong') })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick((): void => {
        OKR_STORE.toggleIdeaDone(this.taskId);
      })

      Column({ space: 5 }) {
        Text(this.task()?.title ?? '')
          .fontSize(13.5)
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.done() ? $r('app.color.okr_text_tertiary') : $r('app.color.okr_text_primary'))
          .decoration({
            type: this.done() ? TextDecorationType.LineThrough : TextDecorationType.None,
            color: $r('app.color.okr_ink_faint')
          })

        if (this.krTitle.length > 0) {
          Row({ space: 5 }) {
            Column()
              .width(4)
              .height(4)
              .borderRadius(2)
              .backgroundColor(this.dotColor())
            Text(this.krTitle)
              .fontSize(9.5)
              .fontColor($r('app.color.okr_text_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick((): void => {
                this.onOpen(this.task()?.krId ?? '');
              })
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Top)
  }
}

/** 卡片内右上角的纯文字入口 */
@ComponentV2
export struct OkrTextLink {
  @Param label: string = '';
  @Event onTap: () => void = (): void => {
  };

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor($r('app.color.okr_text_tertiary'))
      .onClick((): void => {
        this.onTap();
      })
  }
}
