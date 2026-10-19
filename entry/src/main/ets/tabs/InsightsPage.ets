import {
  OKR_STALL_DAYS,
  OkrFlowState,
  okrQuarterLabel,
  okrQuarterTick,
  okrTotalWeeks,
  okrWeekKey,
  okrWeekNumber
} from '../model/OkrAnalytics';
import { OkrKrItem, OkrObjectiveItem, OkrReviewItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import {
  OkrCardHead,
  OkrHairline,
  OkrLedgerLine,
  OkrMeter,
  OkrPageHeader,
  OkrSolidButton
} from '../components/OkrUi';

@ComponentV2
export struct InsightsPage {
  @Local draft: string = '';

  @Event onOpenKr: (krId: string) => void = (_krId: string): void => {
  };

  // ---- 复盘（原「对齐」模块，导航栏不再单列，收进洞察） ----

  private objective(): OkrObjectiveItem | undefined {
    return OKR_STORE.currentObjective();
  }

  private weekKey(): string {
    return okrWeekKey(Date.now());
  }

  private tickPercent(): number {
    const objective: OkrObjectiveItem | undefined = this.objective();
    if (objective === undefined) {
      return 0;
    }
    return okrQuarterTick(OKR_STORE.objectiveStart(objective.id), OKR_STORE.objectiveEnd(objective.id), Date.now());
  }

  private endScale(): number {
    const objective: OkrObjectiveItem | undefined = this.objective();
    if (objective === undefined) {
      return 13;
    }
    const total: number = okrTotalWeeks(OKR_STORE.objectiveStart(objective.id), OKR_STORE.objectiveEnd(objective.id));
    return total > 0 ? total : 13;
  }

  private reviews(): OkrReviewItem[] {
    const objective: OkrObjectiveItem | undefined = this.objective();
    return objective === undefined ? [] : OKR_STORE.reviewsOf(objective.id);
  }

  private savedText(): string {
    const objective: OkrObjectiveItem | undefined = this.objective();
    if (objective === undefined) {
      return '';
    }
    const item: OkrReviewItem | undefined = OKR_STORE.reviewOfWeek(objective.id, this.weekKey());
    return item === undefined ? '' : item.text;
  }

  private lastSavedHint(): string {
    const list: OkrReviewItem[] = this.reviews();
    if (list.length === 0) {
      return '还没记过';
    }
    const days: number = Math.max(0, Math.round((Date.now() - list[0].updatedAt) / 86400000));
    return days === 0 ? '上一条就在今天' : `上一条 ${days} 天前`;
  }

  private saveNote(): void {
    const objective: OkrObjectiveItem | undefined = this.objective();
    if (objective === undefined) {
      return;
    }
    OKR_STORE.saveReview(objective.id, this.weekKey(), this.draft);
    this.draft = '';
  }

  private settleScore(): number {
    const settled: OkrObjectiveItem | undefined = OKR_STORE.settledObjective();
    return settled === undefined ? -1 : OKR_STORE.objectiveProgress(settled.id);
  }

  private settleTitle(): string {
    const settled: OkrObjectiveItem | undefined = OKR_STORE.settledObjective();
    if (settled === undefined) {
      return '暂无已结束的目标';
    }
    return `${okrQuarterLabel(OKR_STORE.objectiveStart(settled.id))} · ${settled.title}`;
  }

  @Builder
  rhythmCard() {
    Column({ space: 0 }) {
      OkrCardHead({ title: '季度节奏', hint: '今天在这里' })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor($r('app.color.okr_rule_strong'))

        Row()
          .width(2)
          .height(22)
          .backgroundColor($r('app.color.okr_text_primary'))
          .offset({ x: `${this.tickPercent()}%` })

        Row()
          .width(2)
          .height(22)
          .backgroundColor($r('app.color.okr_text_primary'))
          .offset({ x: '98%' })
      }
      .width('100%')
      .height(22)
      .margin({ top: 14 })

      Row() {
        Text('今天')
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.okr_text_primary'))
          .position({ x: `${Math.max(0, this.tickPercent() - 4)}%` })

        Text('结算')
          .fontSize(9)
          .fontColor($r('app.color.okr_text_secondary'))
          .width('100%')
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ top: 4 })

      Row() {
        Text('W1')
        Text(`W${Math.max(1, Math.round(this.endScale() / 3))}`)
        Text(`W${this.endScale()}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
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
  noteCard() {
    Column({ space: 0 }) {
      OkrCardHead({ title: '本周快记', hint: this.lastSavedHint() })

      TextArea({
        placeholder: '这周最重要的进展是…',
        text: this.draft.length > 0 ? this.draft : this.savedText()
      })
        .height(90)
        .fontSize(13.5)
        .lineHeight(23)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .margin({ top: 14 })
        .onChange((value: string): void => {
          this.draft = value;
        })

      OkrHairline()
        .margin({ top: 12, bottom: 16 })

      Row() {
        Blank()
        OkrSolidButton({
          label: '保存',
          onTap: (): void => {
            this.saveNote();
          }
        })
      }
      .width('100%')
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
  historyCard() {
    Column() {
      OkrCardHead({ title: '周记' })
        .padding({ left: 18, right: 18, top: 18, bottom: 14 })

      OkrHairline()

      if (this.reviews().length === 0) {
        Text('还没有周记，上面写一句就够了')
          .fontSize(12.5)
          .fontColor($r('app.color.okr_text_tertiary'))
          .padding({ left: 18, right: 18, top: 22, bottom: 22 })
      } else {
        ForEach(this.reviews(), (item: OkrReviewItem, index: number): void => {
          if (index > 0) {
            OkrHairline()
          }
          Row({ space: 14 }) {
            Text(`W${okrWeekNumber(item.weekKey)}`)
              .fontSize(10)
              .fontColor($r('app.color.okr_text_tertiary'))
              .width(34)

            Text(item.text)
              .fontSize(12.5)
              .fontWeight(FontWeight.Lighter)
              .lineHeight(21)
              .layoutWeight(1)
              .fontColor($r('app.color.okr_text_secondary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: 18, right: 18, top: 13, bottom: 13 })
        }, (item: OkrReviewItem): string => item.id)
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
    .clip(true)
  }

  @Builder
  settleCard() {
    Column({ space: 0 }) {
      OkrCardHead({ title: '上次结算', hint: this.settleTitle() })

      Row({ space: 12 }) {
        Text(`${(this.settleScore() < 0 ? 0 : this.settleScore()) / 100}`)
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-1.8)
          .fontColor($r('app.color.okr_text_primary'))

        Text('/1.0')
          .fontSize(14)
          .fontColor($r('app.color.okr_text_tertiary'))
          .alignSelf(ItemAlign.Baseline)
          .margin({ left: -8 })

        Text(this.settleScore() < 0 ? '目标还没结束，等季度收官再来算分' : `达成 ${this.settleScore()}%`)
          .fontSize(12)
          .fontWeight(FontWeight.Lighter)
          .lineHeight(19)
          .layoutWeight(1)
          .fontColor($r('app.color.okr_text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
  }

  private behindKr(): OkrKrItem | undefined {
    let worst: OkrKrItem | undefined = undefined;
    let worstGap: number = -1;
    for (let i = 0; i < OKR_STORE.krs.length; i++) {
      const kr: OkrKrItem = OKR_STORE.krs[i];
      if (OKR_STORE.krState(kr.id) !== OkrFlowState.Behind) {
        continue;
      }
      const gap: number = OKR_STORE.krExpected(kr.id) - OKR_STORE.krProgress(kr.id);
      if (gap > worstGap) {
        worstGap = gap;
        worst = kr;
      }
    }
    return worst;
  }

  private stalledKr(): OkrKrItem | undefined {
    for (let i = 0; i < OKR_STORE.krs.length; i++) {
      if (OKR_STORE.krState(OKR_STORE.krs[i].id) === OkrFlowState.Stalled) {
        return OKR_STORE.krs[i];
      }
    }
    return undefined;
  }

  private countState(state: OkrFlowState): number {
    let count: number = 0;
    for (let i = 0; i < OKR_STORE.krs.length; i++) {
      if (OKR_STORE.krState(OKR_STORE.krs[i].id) === state) {
        count++;
      }
    }
    return count;
  }

  private percentOf(count: number): number {
    if (OKR_STORE.krs.length === 0) {
      return 0;
    }
    return Math.round((count / OKR_STORE.krs.length) * 100);
  }

  private adviceTitle(): string {
    const behind: OkrKrItem | undefined = this.behindKr();
    if (behind !== undefined) {
      const gap: number = OKR_STORE.krExpected(behind.id) - OKR_STORE.krProgress(behind.id);
      return `「${behind.title}」已经落后应达线 ${gap}%`;
    }
    const stalled: OkrKrItem | undefined = this.stalledKr();
    if (stalled !== undefined) {
      const idle: number = Math.round((Date.now() - OKR_STORE.krLastTouch(stalled.id)) / 86400000);
      return `「${stalled.title}」已经 ${idle} 天没有任何进展`;
    }
    if (OKR_STORE.krs.length === 0) {
      return '还没有可分析的数据';
    }
    return '所有关键结果都在应达线以上';
  }

  private adviceBody(): string {
    const behind: OkrKrItem | undefined = this.behindKr();
    if (behind !== undefined) {
      const total: number = OKR_STORE.ideasOfKr(behind.id).length;
      const done: number = total - Math.round(total * OKR_STORE.krProgress(behind.id) / 100);
      return `不是执行力问题——它下面还挂着 ${total} 个任务，只完成了 ${total - done} 个。要么补掉剩下的，要么把它砍掉。`;
    }
    const stalled: OkrKrItem | undefined = this.stalledKr();
    if (stalled !== undefined) {
      return `停滞的 KR 通常不是忘了做，是没有下一步动作。给它定一个本周之内能做完的小任务。`;
    }
    return '现在的节奏是健康的：每个 KR 的实际进度都不低于应达线。';
  }

  private adviceAction(): string {
    const behind: OkrKrItem | undefined = this.behindKr();
    if (behind !== undefined) {
      return `建议：本周给「${behind.title}」补一个任务，或者直接把它移出这个季度。`;
    }
    const stalled: OkrKrItem | undefined = this.stalledKr();
    if (stalled !== undefined) {
      return `建议：把「${stalled.title}」拆成一个 ${OKR_STALL_DAYS} 天内能完成的小任务。`;
    }
    return '建议：保持当前节奏，季末一次性复盘。';
  }

  private objectiveTaskCount(objectiveId: string): number {
    let count: number = 0;
    for (let i = 0; i < OKR_STORE.ideas.length; i++) {
      if (OKR_STORE.ideas[i].krId.length > 0
        && OKR_STORE.krObjectiveId(OKR_STORE.ideas[i].krId) === objectiveId) {
        count++;
      }
    }
    return count;
  }

  private maxTaskCount(): number {
    let max: number = 1;
    const list: OkrObjectiveItem[] = OKR_STORE.activeObjectives();
    for (let i = 0; i < list.length; i++) {
      const count: number = this.objectiveTaskCount(list[i].id);
      if (count > max) {
        max = count;
      }
    }
    return max;
  }

  private shortName(objective: OkrObjectiveItem, index: number): string {
    const title: string = objective.title.length > 6 ? objective.title.substring(0, 6) : objective.title;
    return `O${index + 1} · ${title}`;
  }

  @Builder
  worstCard() {
    Column({ space: 0 }) {
      OkrCardHead({
        title: this.behindKr() === undefined ? '当前没有落后的 KR' : OKR_STORE.krTitle(this.behindKr()?.id ?? ''),
        hint: this.behindKr() === undefined ? '' : '需要处理'
      })

      if (this.behindKr() !== undefined) {
        OkrMeter({
          actual: OKR_STORE.krProgress(this.behindKr()?.id ?? ''),
          expected: OKR_STORE.krExpected(this.behindKr()?.id ?? ''),
          state: OkrFlowState.Behind
        })
        .margin({ top: 14 })

        OkrLedgerLine({
          leftText: `实际 ${OKR_STORE.krProgress(this.behindKr()?.id ?? '')}%`,
          rightText: '',
          tone: OkrFlowState.Behind
        })
        .margin({ top: 2 })
      } else {
        Text('所有关键结果都不低于应达线')
          .fontSize(12.5)
          .fontWeight(FontWeight.Lighter)
          .fontColor($r('app.color.okr_text_secondary'))
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
    .onClick((): void => {
      const behind: OkrKrItem | undefined = this.behindKr();
      if (behind !== undefined) {
        this.onOpenKr(behind.id);
      }
    })
  }

  @Builder
  distCard() {
    Column({ space: 0 }) {
      OkrCardHead({ title: `${OKR_STORE.krs.length} 个 KR 现在的状态` })

      Row() {
        Row()
          .layoutWeight(Math.max(1, this.percentOf(this.countState(OkrFlowState.OnTrack))))
          .height(6)
          .backgroundColor($r('app.color.okr_primary'))
        Row()
          .layoutWeight(Math.max(1, this.percentOf(this.countState(OkrFlowState.Stalled))))
          .height(6)
          .backgroundColor($r('app.color.okr_neutral'))
        Row()
          .layoutWeight(Math.max(1, this.percentOf(this.countState(OkrFlowState.Behind))))
          .height(6)
          .backgroundColor($r('app.color.okr_danger'))
      }
      .width('100%')
      .height(6)
      .borderRadius(3)
      .clip(true)
      .margin({ top: 14 })

      Row() {
        StatCell({ value: `${this.countState(OkrFlowState.OnTrack)}`, label: '推进中' })
        Divider()
          .vertical(true)
          .strokeWidth(1)
          .color($r('app.color.okr_divider'))
          .height(28)
        StatCell({ value: `${this.countState(OkrFlowState.Stalled)}`, label: '停滞' })
        Divider()
          .vertical(true)
          .strokeWidth(1)
          .color($r('app.color.okr_divider'))
          .height(28)
        StatCell({ value: `${this.countState(OkrFlowState.Behind)}`, label: '落后' })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })
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
  adviceCard() {
    Column({ space: 0 }) {
      Text(this.adviceTitle())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .lineHeight(22)
        .fontColor($r('app.color.okr_text_primary'))

      Text(this.adviceBody())
        .fontSize(12.5)
        .fontWeight(FontWeight.Lighter)
        .lineHeight(21)
        .fontColor($r('app.color.okr_text_secondary'))
        .margin({ top: 8 })

      Text(this.adviceAction())
        .fontSize(12.5)
        .lineHeight(20)
        .fontColor($r('app.color.okr_text_primary'))
        .backgroundColor($r('app.color.okr_track'))
        .borderRadius(10)
        .padding(12)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 18, top: 18, bottom: 18 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .borderWidth({ top: 1, right: 1, bottom: 1, left: 2 })
    .borderColor({
      top: $r('app.color.okr_divider'),
      right: $r('app.color.okr_divider'),
      bottom: $r('app.color.okr_divider'),
      left: $r('app.color.okr_text_primary')
    })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
  }

  @Builder
  effortCard() {
    Column({ space: 0 }) {
      OkrCardHead({
        title: '各目标下的任务',
        hint: `共 ${OKR_STORE.ideas.length} 条`
      })

      Column({ space: 13 }) {
        ForEach(OKR_STORE.activeObjectives(), (objective: OkrObjectiveItem, index: number): void => {
          Row({ space: 12 }) {
            Text(this.shortName(objective, index))
              .fontSize(12.5)
              .width(82)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('app.color.okr_text_secondary'))

            Row() {
              Row()
                .width(`${Math.round(this.objectiveTaskCount(objective.id) / this.maxTaskCount() * 100)}%`)
                .height(6)
                .borderRadius(3)
                .backgroundColor($r('app.color.okr_text_primary'))
            }
            .layoutWeight(1)
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('app.color.okr_track'))

            Text(`${this.objectiveTaskCount(objective.id)}`)
              .fontSize(10.5)
              .width(26)
              .textAlign(TextAlign.End)
              .fontColor($r('app.color.okr_text_tertiary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }, (objective: OkrObjectiveItem): string => objective.id)
      }
      .width('100%')
      .margin({ top: 16 })

      OkrLedgerLine({
        leftText: this.effortHint(),
        rightText: ''
      })
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
  }

  private effortHint(): string {
    const list: OkrObjectiveItem[] = OKR_STORE.activeObjectives();
    if (list.length < 2) {
      return '多设一个目标，才能看出注意力分给了谁';
    }
    let maxCount: number = 0;
    let maxIndex: number = -1;
    let total: number = 0;
    for (let i = 0; i < list.length; i++) {
      const count: number = this.objectiveTaskCount(list[i].id);
      total = total + count;
      if (count > maxCount) {
        maxCount = count;
        maxIndex = i;
      }
    }
    if (total === 0 || maxIndex < 0) {
      return '还没有任务落到目标上';
    }
    return `O${maxIndex + 1} 拿到了 ${Math.round(maxCount / total * 100)}% 的任务`;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        OkrPageHeader({
          eyebrow: '自动记录 · 实时计算',
          title: '洞察',
          sub: '不是给你看的报表，是给你下一步动作的'
        })

        this.worstCard()

        this.distCard()

        this.adviceCard()

        this.effortCard()

        this.rhythmCard()

        this.noteCard()

        this.historyCard()

        this.settleCard()
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}

@ComponentV2
struct StatCell {
  @Param value: string = '';
  @Param label: string = '';

  build() {
    Column({ space: 3 }) {
      Text(this.value)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(-0.6)
        .fontColor($r('app.color.okr_text_primary'))
      Text(this.label)
        .fontSize(11.5)
        .fontColor($r('app.color.okr_text_tertiary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
}
