import {
  OkrKrItem,
  OkrObjectiveItem,
  okrFormatDate,
  okrNow
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrProgressTrack } from './OkrCommon';

@ComponentV2
export struct KrRow {
  @Param krId: string = '';
  @Event onOpenKr: (krId: string) => void = (krId: string): void => {
  };

  private kr(): OkrKrItem | undefined {
    return OKR_STORE.findKr(this.krId);
  }

  private titleText(): string {
    const found: OkrKrItem | undefined = this.kr();
    return found === undefined ? '' : found.title;
  }

  private subText(): string {
    const found: OkrKrItem | undefined = this.kr();
    if (found === undefined) {
      return '';
    }
    const linked: number = OKR_STORE.ideasOfKr(found.id).length;
    const progress: number = OKR_STORE.krProgress(found.id);
    return `进度 ${progress}% · 关联 ${linked} 项`;
  }

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.titleText())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.okr_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subText())
          .fontSize(11)
          .fontColor($r('app.color.okr_text_tertiary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      OkrProgressTrack({ percent: OKR_STORE.krProgress(this.krId), barHeight: 5 })
        .width(72)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.onOpenKr(this.krId);
    })
  }
}

@ComponentV2
export struct ObjectiveCard {
  @Param objectiveId: string = '';
  @Event onOpenKr: (krId: string) => void = (krId: string): void => {
  };
  @Local krComposerOpen: boolean = false;
  @Local krDraft: string = '';
  @Local krTarget: string = '';
  @Local krDue: number = 0;

  private obj(): OkrObjectiveItem | undefined {
    return OKR_STORE.findObjective(this.objectiveId);
  }

  private krList(): OkrKrItem[] {
    return OKR_STORE.krsOfObjective(this.objectiveId);
  }

  private titleText(): string {
    const found: OkrObjectiveItem | undefined = this.obj();
    return found === undefined ? '' : found.title;
  }

  private periodText(): string {
    const found: OkrObjectiveItem | undefined = this.obj();
    if (found === undefined || found.period.length === 0) {
      return '目标';
    }
    return found.period;
  }

  private descText(): string {
    const found: OkrObjectiveItem | undefined = this.obj();
    if (found === undefined) {
      return '';
    }
    return found.desc;
  }

  private progress(): number {
    return OKR_STORE.objectiveProgress(this.objectiveId);
  }

  private toggleComposer(): void {
    this.krComposerOpen = !this.krComposerOpen;
    this.krDraft = '';
    this.krTarget = '';
    this.krDue = 0;
  }

  private createKr(): void {
    if (this.krDraft.trim().length === 0) {
      return;
    }
    OKR_STORE.addKr(this.objectiveId, this.krDraft.trim(), this.krTarget.trim(), this.krDue);
    this.krComposerOpen = false;
    this.krDraft = '';
    this.krTarget = '';
    this.krDue = 0;
  }

  private quickDue(): void {
    const day: number = 86400000;
    if (this.krDue > 0) {
      this.krDue = 0;
      return;
    }
    this.krDue = okrNow() + 7 * day;
  }

  private dueLabel(): string {
    if (this.krDue <= 0) {
      return '设 7 天截止';
    }
    return okrFormatDate(this.krDue);
  }

  build() {
    Column({ space: 10 }) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.periodText())
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.okr_primary'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(6)
            .backgroundColor($r('app.color.okr_primary_soft'))
          Text(`${this.progress()}%`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.okr_primary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)

        Text(this.titleText())
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))

        if (this.descText().length > 0) {
          Text(this.descText())
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.okr_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      OkrProgressTrack({ percent: this.progress(), barColor: $r('app.color.okr_primary') })

      Column() {
        if (this.krList().length === 0) {
          Text('还没有关键结果')
            .fontSize(12)
            .fontColor($r('app.color.okr_text_tertiary'))
            .padding({ top: 8, bottom: 8 })
        } else {
          ForEach(this.krList(), (krItem: OkrKrItem) => {
            KrRow({
              krId: krItem.id,
              onOpenKr: (id: string): void => {
                this.onOpenKr(id);
              }
            })
          }, (krItem: OkrKrItem): string => krItem.id)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.krComposerOpen) {
        Column({ space: 8 }) {
          TextInput({ placeholder: '关键结果，例如「连续记录 30 天」', text: this.krDraft })
            .height(40)
            .fontSize(13)
            .backgroundColor($r('app.color.okr_bg'))
            .borderRadius(8)
            .onChange((value: string): void => {
              this.krDraft = value;
            })
          TextInput({ placeholder: '衡量指标（选填），例如「30 篇」', text: this.krTarget })
            .height(40)
            .fontSize(13)
            .backgroundColor($r('app.color.okr_bg'))
            .borderRadius(8)
            .onChange((value: string): void => {
              this.krTarget = value;
            })
          Row({ space: 8 }) {
            Button(this.dueLabel())
              .height(32)
              .fontSize(12)
              .backgroundColor($r('app.color.okr_track'))
              .fontColor($r('app.color.okr_text_secondary'))
              .onClick((): void => {
                this.quickDue();
              })
            Button('创建')
              .height(32)
              .fontSize(12)
              .backgroundColor($r('app.color.okr_primary'))
              .fontColor('#FFFFFF')
              .layoutWeight(1)
              .onClick((): void => {
                this.createKr();
              })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Button('＋ 添加关键结果')
          .height(34)
          .width('100%')
          .fontSize(13)
          .backgroundColor($r('app.color.okr_primary_soft'))
          .fontColor($r('app.color.okr_primary'))
          .onClick((): void => {
            this.toggleComposer();
          })
      }
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
  }
}
