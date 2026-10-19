import {
  okrQuarterLabel,
  okrQuarterTick,
  okrTotalWeeks,
  okrWeekKey,
  okrWeekNumber
} from '../model/OkrAnalytics';
import { OkrObjectiveItem, OkrReviewItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrCardHead, OkrHairline, OkrPageHeader, OkrSolidButton } from '../components/OkrUi';

@ComponentV2
export struct ReviewPage {
  @Local draft: string = '';

  private objective(): OkrObjectiveItem | undefined {
    return OKR_STORE.currentObjective();
  }

  private weekKey(): string {
    return okrWeekKey(Date.now());
  }

  private weekNumberLabel(): string {
    const objective: OkrObjectiveItem | undefined = this.objective();
    const start: number = objective === undefined ? 0 : OKR_STORE.objectiveStart(objective.id);
    const end: number = objective === undefined ? 0 : OKR_STORE.objectiveEnd(objective.id);
    const total: number = okrTotalWeeks(start, end);
    const now: number = Date.now();
    let passed: number = 0;
    if (start > 0 && end > start && now > start) {
      passed = Math.min(total, Math.max(1, Math.ceil((now - start) / (7 * 86400000))));
    } else {
      passed = Math.max(1, okrWeekNumber(this.weekKey()));
    }
    return `第 ${passed} 周 / 共 ${total > 0 ? total : '—'} 周`;
  }

  private objectiveLabel(): string {
    const objective: OkrObjectiveItem | undefined = this.objective();
    if (objective === undefined) {
      return '还没有目标';
    }
    return okrQuarterLabel(OKR_STORE.objectiveStart(objective.id));
  }

  private reviews(): OkrReviewItem[] {
    const objective: OkrObjectiveItem | undefined = this.objective();
    if (objective === undefined) {
      return [];
    }
    return OKR_STORE.reviewsOf(objective.id);
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
    if (days === 0) {
      return '上一条就在今天';
    }
    return `上一条 ${days} 天前`;
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
  rulerCard() {
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
        Text(this.midScale())
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

  private midScale(): string {
    return `W${Math.max(1, Math.round(this.endScale() / 3))}`;
  }

  @Builder
  noteCard() {
    Column({ space: 0 }) {
      OkrCardHead({ title: '本周快记', hint: this.lastSavedHint() })

      TextArea({
        placeholder: '这周最重要的进展是…',
        text: this.draft.length > 0 ? this.draft : this.savedText()
      })
        .height(96)
        .fontSize(13.5)
        .lineHeight(23)
        .backgroundColor(Color.Transparent)
        .border({ width: 0 })
        .padding(0)
        .margin({ top: 14 })
        .onChange((value: string): void => {
          this.draft = value;
        })

      Divider()
        .strokeWidth(1)
        .color($r('app.color.okr_rule_strong'))
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
          .padding({ left: 18, right: 18, top: 24, bottom: 24 })
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
          .fontWeight(FontWeight.Normal)
          .fontColor($r('app.color.okr_text_tertiary'))
          .alignSelf(ItemAlign.Baseline)
          .margin({ left: -8 })

        Text(this.settleScore() < 0 ? '目标还没结束，等季度收官再来算分'
          : `达成 ${this.settleScore()}%`)
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

  build() {
    Scroll() {
      Column({ space: 12 }) {
        OkrPageHeader({
          eyebrow: `${this.objectiveLabel()} · ${this.weekNumberLabel()}`,
          title: '对齐',
          sub: '每周一句话，季末才算分'
        })

        this.rulerCard()

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
