import {
  OkrProjectItem,
  OkrPriority,
  okrDay,
  okrNow,
  okrParseTags,
  okrPriorityColor,
  okrPriorityLabel,
  okrSameDay,
  okrTagColor
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrSelectChip, OkrTagChip } from './OkrCommon';

@ComponentV2
export struct QuickCapture {
  @Local draft: string = '';
  @Local priority: number = OkrPriority.Medium;
  @Local due: number = 0;
  @Local projectId: string = '';
  @Local projectPickerOpen: boolean = false;

  private levels(): number[] {
    return [OkrPriority.Low, OkrPriority.Medium, OkrPriority.High];
  }

  private dueOptions(): string[] {
    return ['今天', '3 天后', '本周', '清除'];
  }

  private draftTags(): string[] {
    return okrParseTags(this.draft).tags;
  }

  private projects(): OkrProjectItem[] {
    return OKR_STORE.projectList(false);
  }

  private projectLabel(): string {
    if (this.projectId.length === 0) {
      return '无项目';
    }
    const title: string = OKR_STORE.projectTitle(this.projectId);
    return title.length > 0 ? title : '无项目';
  }

  private dueDaysOf(label: string): number {
    if (label === '今天') {
      return 0;
    }
    if (label === '3 天后') {
      return 3;
    }
    if (label === '本周') {
      const rest: number = 7 - new Date().getDay();
      return Math.max(1, rest);
    }
    return -1;
  }

  private applyDue(label: string): void {
    const days: number = this.dueDaysOf(label);
    if (days < 0) {
      this.due = 0;
      return;
    }
    this.due = okrDay(days);
  }

  private dueActive(label: string): boolean {
    if (label === '清除') {
      return this.due === 0;
    }
    if (this.due === 0) {
      return false;
    }
    return okrSameDay(this.due, this.dueDaysOf(label));
  }

  private canSubmit(): boolean {
    return this.draft.trim().length > 0;
  }

  private submit(): void {
    if (!this.canSubmit()) {
      return;
    }
    OKR_STORE.addIdea(this.draft, this.priority, this.due, this.projectId);
    this.draft = '';
    this.due = 0;
    this.priority = OkrPriority.Medium;
    this.getUIContext().getPromptAction().showToast({ message: '已加入收件箱' });
  }

  @Builder
  projectRow() {
    Scroll() {
      Row({ space: 8 }) {
        Text('项目')
          .fontSize(12)
          .fontColor($r('app.color.okr_text_tertiary'))
        ForEach(this.projects(), (item: OkrProjectItem) => {
          Row({ space: 5 }) {
            Row()
              .width(8)
              .height(8)
              .backgroundColor(okrTagColor(item.colorIndex))
              .borderRadius(4)
            Text(item.title)
              .fontSize(12)
              .fontColor(this.projectId === item.id
                ? $r('app.color.okr_project')
                : $r('app.color.okr_text_secondary'))
          }
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor(this.projectId === item.id
            ? $r('app.color.okr_project_soft')
            : $r('app.color.okr_track'))
          .onClick((): void => {
            this.projectId = this.projectId === item.id ? '' : item.id;
          })
        }, (item: OkrProjectItem): string => item.id)
      }
    }
    .width('100%')
    .height(30)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  @Builder
  optionRow() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.levels(), (level: number): void => {
          OkrSelectChip({
            chipText: okrPriorityLabel(level),
            active: this.priority === level,
            chipColor: okrPriorityColor(level),
            onPick: (): void => {
              this.priority = level;
            }
          })
        }, (level: number): string => `${level}`)
        ForEach(this.dueOptions(), (label: string): void => {
          OkrSelectChip({
            chipText: label,
            active: this.dueActive(label),
            chipColor: okrTagColor(1),
            onPick: (): void => {
              this.applyDue(label);
            }
          })
        }, (label: string): string => label)
      }
    }
    .width('100%')
    .height(34)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  build() {
    Column({ space: 10 }) {
      Column({ space: 8 }) {
        TextArea({
          placeholder: '想到什么就写下来，用 #标签 归类',
          text: this.draft
        })
          .width('100%')
          .height(112)
          .fontSize(15)
          .borderRadius(12)
          .backgroundColor($r('app.color.okr_bg'))
          .onChange((value: string): void => {
            this.draft = value;
          })
          .onSubmit((): void => {
            this.submit();
          })

        if (this.projects().length > 0) {
          Row({ space: 8 }) {
            Text(`归属：${this.projectLabel()}`)
              .fontSize(12)
              .fontColor($r('app.color.okr_project'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button('不归属')
              .height(30)
              .fontSize(11)
              .backgroundColor($r('app.color.okr_track'))
              .fontColor($r('app.color.okr_text_secondary'))
              .onClick((): void => {
                this.projectId = '';
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.okr_bg'))
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      if (this.projects().length > 0) {
        this.projectRow()
      }
      this.optionRow()

      Button(this.canSubmit() ? '记下' : '先写点什么')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('app.color.okr_primary'))
        .fontColor($r('app.color.okr_on_primary'))
        .enabled(this.canSubmit())
        .onClick((): void => {
          this.submit();
        })

      if (this.draftTags().length > 0) {
        Row({ space: 6 }) {
          Text('识别到')
            .fontSize(11)
            .fontColor($r('app.color.okr_text_tertiary'))
          ForEach(this.draftTags(), (tagName: string): void => {
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
    }
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
  }
}
