import {
  OkrPriority,
  okrDay,
  okrNow,
  okrParseTags,
  okrPriorityColor,
  okrPriorityLabel,
  okrSameDay
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrSelectChip, OkrTagChip } from './OkrCommon';

@ComponentV2
export struct QuickCapture {
  @Local draft: string = '';
  @Local priority: number = OkrPriority.Medium;
  @Local due: number = 0;

  private levels(): number[] {
    return [OkrPriority.Low, OkrPriority.Medium, OkrPriority.High];
  }

  private dueOptions(): string[] {
    return ['今天', '3 天后', '本周', '清除'];
  }

  private draftTags(): string[] {
    return okrParseTags(this.draft).tags;
  }

  private dueDaysOf(label: string): number {
    if (label === '今天') {
      return 0;
    }
    if (label === '3 天后') {
      return 3;
    }
    if (label === '本周') {
      return 7 - new Date(okrNow() + 86400000).getDay();
    }
    return -1;
  }

  private applyDue(label: string): void {
    if (label === '清除') {
      this.due = 0;
      return;
    }
    this.due = okrDay(this.dueDaysOf(label));
  }

  private dueActive(label: string): boolean {
    if (label === '清除') {
      return false;
    }
    return okrSameDay(this.due, okrDay(this.dueDaysOf(label)));
  }

  private canSubmit(): boolean {
    return this.draft.trim().length > 0;
  }

  private submit(): void {
    if (!this.canSubmit()) {
      return;
    }
    OKR_STORE.addIdea(this.draft, this.priority, this.due);
    this.draft = '';
    this.due = 0;
    this.priority = OkrPriority.Medium;
    this.getUIContext().getPromptAction().showToast({ message: '已加入收件箱' });
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '想到什么就写下来，用 #标签 归类', text: this.draft })
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .borderRadius(21)
          .enterKeyType(EnterKeyType.Send)
          .backgroundColor($r('app.color.okr_bg'))
          .onChange((value: string): void => {
            this.draft = value;
          })
          .onSubmit((enterKey: EnterKeyType): void => {
            this.submit();
          })
        Button('记下')
          .height(42)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('app.color.okr_primary'))
          .fontColor('#FFFFFF')
          .onClick((): void => {
            this.submit();
          })
      }
      .width('100%')

      if (this.draftTags().length > 0) {
        Row({ space: 6 }) {
          Text('识别到')
            .fontSize(11)
            .fontColor($r('app.color.okr_text_tertiary'))
          ForEach(this.draftTags(), (tagName: string) => {
            OkrTagChip({
              chipText: tagName,
              colorIndex: OKR_STORE.tagColorIndex(tagName),
              solid: true
            })
          }, (tagName: string): string => tagName)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.levels(), (level: number) => {
            OkrSelectChip({
              chipText: okrPriorityLabel(level),
              active: this.priority === level,
              chipColor: okrPriorityColor(level),
              onPick: (): void => {
                this.priority = level;
              }
            })
          }, (level: number): string => `${level}`)

          ForEach(this.dueOptions(), (label: string) => {
            OkrSelectChip({
              chipText: label,
              active: this.dueActive(label),
              chipColor: '#12B886',
              onPick: (): void => {
                this.applyDue(label);
              }
            })
          }, (label: string): string => label)
        }
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(30)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
  }
}
