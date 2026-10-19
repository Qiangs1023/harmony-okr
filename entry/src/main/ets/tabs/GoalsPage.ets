import {
  OkrFlowState,
  okrFlowLabel,
  okrQuarterLabel,
  okrTotalWeeks
} from '../model/OkrAnalytics';
import { OkrKrItem, OkrObjectiveItem, okrFormatDate } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrCardHead, OkrHairline, OkrLedgerLine, OkrMeter, OkrPageHeader } from '../components/OkrUi';
import { KrLine } from './TodayPage';

@ComponentV2
export struct GoalsPage {
  @Event onOpenKr: (krId: string) => void = (_krId: string): void => {
  };
  @Event onOpenObjective: (objectiveId: string) => void = (_objectiveId: string): void => {
  };
  @Event onCompose: () => void = (): void => {
  };

  private activeList(): OkrObjectiveItem[] {
    return OKR_STORE.activeObjectives();
  }

  private krTotal(): number {
    return OKR_STORE.krs.length;
  }

  private objectiveLabel(): string {
    const list: OkrObjectiveItem[] = this.activeList();
    if (list.length === 0) {
      return '还没有设定周期';
    }
    const first: OkrObjectiveItem = list[0];
    const start: number = OKR_STORE.objectiveStart(first.id);
    const end: number = OKR_STORE.objectiveEnd(first.id);
    if (start <= 0 || end <= 0) {
      return okrQuarterLabel(start);
    }
    return `${okrQuarterLabel(start)} · ${okrFormatDate(start).substring(5)} – ${okrFormatDate(end).substring(5)}`;
  }

  private overallState(): OkrFlowState {
    const actual: number = OKR_STORE.overallProgress();
    const expected: number = OKR_STORE.overallExpected();
    let worst: OkrFlowState = OkrFlowState.OnTrack;
    for (let i = 0; i < OKR_STORE.krs.length; i++) {
      const state: OkrFlowState = OKR_STORE.krState(OKR_STORE.krs[i].id);
      if (state === OkrFlowState.Behind) {
        return OkrFlowState.Behind;
      }
      if (state === OkrFlowState.Stalled) {
        worst = OkrFlowState.Stalled;
      }
    }
    if (expected < 0 && actual >= 0) {
      return worst;
    }
    return worst;
  }

  private rhythmLine(): string {
    const list: OkrObjectiveItem[] = this.activeList();
    if (list.length === 0) {
      return '先给目标定一个起止时间';
    }
    const start: number = OKR_STORE.objectiveStart(list[0].id);
    const end: number = OKR_STORE.objectiveEnd(list[0].id);
    if (start <= 0 || end <= 0) {
      return '未设定节奏';
    }
    const total: number = okrTotalWeeks(start, end);
    const passed: number = Math.min(total, Math.max(0, Math.ceil((Date.now() - start) / (7 * 86400000))));
    return `第 ${passed} 周 / 共 ${total} 周 · 还剩 ${Math.max(0, total - passed)} 周`;
  }

  @Builder
  overallCard() {
    Column({ space: 0 }) {
      Row() {
        Text('整体进度')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.okr_text_secondary'))
        Blank()
        Text(`${OKR_STORE.overallProgress()}%`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.4)
          .fontColor($r('app.color.okr_text_primary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      OkrMeter({
        actual: OKR_STORE.overallProgress(),
        expected: OKR_STORE.overallExpected(),
        state: this.overallState()
      })
      .margin({ top: 14 })

      OkrLedgerLine({
        leftText: `${okrFlowLabel(this.overallState(), OKR_STORE.overallProgress(), OKR_STORE.overallExpected())} · ${this.rhythmLine()}`,
        rightText: ''
      })
      .margin({ top: 2 })
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
  legendRow() {
    Row({ space: 16 }) {
      Row({ space: 6 }) {
        Row()
          .width(18)
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.okr_primary'))
        Text('实际进度')
          .fontSize(9.5)
          .fontColor($r('app.color.okr_text_tertiary'))
      }
      Row({ space: 6 }) {
        Row()
          .width(2)
          .height(10)
          .backgroundColor($r('app.color.okr_text_primary'))
        Text('应达线')
          .fontSize(9.5)
          .fontColor($r('app.color.okr_text_tertiary'))
      }
    }
    .alignItems(VerticalAlign.Center)
    .margin({ top: 16 })
  }

  @Builder
  objectiveBlock(objective: OkrObjectiveItem, index: number, krList: OkrKrItem[]) {
    Column() {
      Row({ space: 12 }) {
        Text(`O${index + 1}`)
          .fontSize(10)
          .letterSpacing(1)
          .fontColor($r('app.color.okr_text_tertiary'))
          .padding({ top: 4 })

        Column({ space: 4 }) {
          Text(objective.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.2)
            .lineHeight(22)
            .fontColor($r('app.color.okr_text_primary'))

          if (objective.desc.length > 0) {
            Text(objective.desc)
              .fontSize(12.5)
              .fontWeight(FontWeight.Lighter)
              .lineHeight(20)
              .fontColor($r('app.color.okr_text_tertiary'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(`${OKR_STORE.objectiveProgress(objective.id)}%`)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.5)
          .fontColor($r('app.color.okr_text_primary'))
          .padding({ top: 1 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 18, right: 18, top: 20, bottom: 4 })
      .onClick((): void => {
        this.onOpenObjective(objective.id);
      })

      if (krList.length === 0) {
        Text('还没有关键结果')
          .fontSize(12)
          .fontColor($r('app.color.okr_text_tertiary'))
          .padding({ left: 18, right: 18, top: 12, bottom: 20 })
      } else {
        ForEach(krList, (kr: OkrKrItem, krIndex: number): void => {
          if (krIndex > 0) {
            OkrHairline()
          }
          Column() {
            KrLine({ krId: kr.id })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 16, bottom: 16 })
          .onClick((): void => {
            this.onOpenKr(kr.id);
          })
        }, (kr: OkrKrItem): string => kr.id)
      }
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column({ space: 12 }) {
          Column() {
            OkrPageHeader({
              eyebrow: this.objectiveLabel(),
              title: '目标',
              sub: `${this.activeList().length} 个方向 · ${this.krTotal()} 个关键结果`
            })
            this.legendRow()
          }
          .width('100%')

          this.overallCard()

          if (this.activeList().length === 0) {
            Column({ space: 10 }) {
              OkrCardHead({ title: '还没有目标' })
              Text('点右下角的加号，先写一句这个季度想做成什么')
                .fontSize(12.5)
                .fontWeight(FontWeight.Lighter)
                .lineHeight(20)
                .fontColor($r('app.color.okr_text_tertiary'))
            }
            .width('100%')
            .padding(18)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.okr_card'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.okr_divider') })
          } else {
            Column() {
              ForEach(this.activeList(), (objective: OkrObjectiveItem, index: number): void => {
                if (index > 0) {
                  OkrHairline()
                }
                this.objectiveBlock(objective, index, OKR_STORE.krsOfObjective(objective.id))
              }, (objective: OkrObjectiveItem): string => objective.id)
            }
            .width('100%')
            .backgroundColor($r('app.color.okr_card'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.okr_divider') })
            .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
            .clip(true)
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Button('＋')
        .width(52)
        .height(52)
        .fontSize(26)
        .borderRadius(26)
        .backgroundColor($r('app.color.okr_text_primary'))
        .fontColor($r('app.color.okr_on_primary'))
        .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 4 })
        .margin({ right: 20, bottom: 20 })
        .onClick((): void => {
          this.onCompose();
        })
    }
    .width('100%')
    .height('100%')
  }
}
