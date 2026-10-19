import {
  OkrProjectItem,
  OkrPriority,
  OkrTagItem,
  okrDay,
  okrNow,
  okrParseTags,
  okrPriorityColor,
  okrPriorityLabel,
  okrSameDay,
  okrTagColor
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrSelectChip } from './OkrCommon';

const TAG_CHIP_WIDTH: number = 76;
const TAG_CHIP_GAP: number = 8;

@ComponentV2
export struct QuickCapture {
  @Event onDone: () => void = (): void => {
  };
  @Local draft: string = '';
  @Local priority: number = OkrPriority.Medium;
  @Local due: number = 0;
  @Local projectId: string = '';
  @Local pickedTags: string[] = [];
  @Local dragFrom: number = -1;

  private levels(): number[] {
    return [OkrPriority.Low, OkrPriority.Medium, OkrPriority.High];
  }

  private dueOptions(): string[] {
    return ['今天', '3 天后', '本周', '清除'];
  }

  private draftTags(): string[] {
    return okrParseTags(this.draft).tags;
  }

  private tagList(): OkrTagItem[] {
    return OKR_STORE.tags;
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

  private isPicked(name: string): boolean {
    return this.pickedTags.indexOf(name) >= 0;
  }

  private toggleTag(name: string): void {
    if (this.isPicked(name)) {
      this.pickedTags = this.pickedTags.filter((item: string): boolean => item !== name);
      return;
    }
    this.pickedTags = this.pickedTags.concat([name]);
  }

  private syncDraftTags(): void {
    const parsed: string[] = this.draftTags();
    if (parsed.length === 0) {
      return;
    }
    const merged: string[] = this.pickedTags.slice();
    for (let i = 0; i < parsed.length; i++) {
      if (merged.indexOf(parsed[i]) < 0) {
        merged.push(parsed[i]);
      }
    }
    if (merged.length !== this.pickedTags.length) {
      this.pickedTags = merged;
    }
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
    const tags: string[] = this.pickedTags.slice();
    let title: string = this.draft.trim();
    // 正文里已经写了 #标签 时，避免拼进标题造成重复
    const parsed: string[] = this.draftTags();
    if (parsed.length > 0) {
      const body: string = okrParseTags(this.draft).title;
      title = body.length > 0 ? body : this.draft.trim();
    } else if (tags.length > 0) {
      const suffix: string[] = [];
      for (let i = 0; i < tags.length; i++) {
        suffix.push(`#${tags[i]}`);
      }
      title = `${title} ${suffix.join(' ')}`;
    }
    OKR_STORE.addIdea(title, this.priority, this.due, this.projectId);
    this.draft = '';
    this.due = 0;
    this.priority = OkrPriority.Medium;
    this.pickedTags = [];
    this.getUIContext().getPromptAction().showToast({ message: '已加入收件箱' });
    this.onDone();
  }

  @Builder
  projectRow() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.projects(), (item: OkrProjectItem): void => {
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

  @Builder
  tagPicker() {
    if (this.tagList().length === 0) {
      Text('还没有标签，在标题里写 #标签 就能自动创建')
        .fontSize(11)
        .fontColor($r('app.color.okr_text_tertiary'))
        .width('100%')
    } else {
    Column({ space: 4 }) {
      Row() {
        Text('标签')
          .fontSize(11)
          .fontColor($r('app.color.okr_text_tertiary'))
        Text('长按可拖动排序')
          .fontSize(10)
          .fontColor($r('app.color.okr_text_tertiary'))
      }
      .width('100%')

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.tagList(), (item: OkrTagItem, index: number): void => {
            Text(item.name)
              .fontSize(12)
              .width(TAG_CHIP_WIDTH)
              .height(32)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .borderRadius(16)
              .fontColor(this.isPicked(item.name)
                ? $r('app.color.okr_on_primary')
                : $r('app.color.okr_text_secondary'))
              .backgroundColor(this.isPicked(item.name)
                ? okrTagColor(item.colorIndex)
                : $r('app.color.okr_track'))
              .opacity(this.dragFrom === index ? 0.4 : 1)
              .draggable(true)
              .onDragStart((): void => {
                this.dragFrom = index;
              })
              .onClick((): void => {
                this.toggleTag(item.name);
              })
          }, (item: OkrTagItem): string => item.name)
        }
      }
      .width('100%')
      .height(34)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .onDrop((event: DragEvent): void => {
        // DragEvent.getX() 返回的是像素，而标签宽度常量是 vp，需换算后再算落点
        const pitch: number = vp2px(TAG_CHIP_WIDTH + TAG_CHIP_GAP);
        let target: number = Math.round(event.getX() / pitch);
        const size: number = this.tagList().length;
        if (target < 0) {
          target = 0;
        }
        if (target > size - 1) {
          target = size - 1;
        }
        if (this.dragFrom >= 0) {
          OKR_STORE.moveTag(this.dragFrom, target);
        }
        this.dragFrom = -1;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column({ space: 10 }) {
      TextArea({
        placeholder: '想到什么就写下来，用 #标签 归类',
        text: this.draft
      })
        .width('100%')
        .height(64)
        .fontSize(14)
        .borderRadius(12)
        .backgroundColor($r('app.color.okr_bg'))
        .onChange((value: string): void => {
          this.draft = value;
          this.syncDraftTags();
        })
        .onSubmit((): void => {
          this.submit();
        })

      this.optionRow()

      if (this.projects().length > 0) {
        this.projectRow()
      }

      this.tagPicker()

      Button(this.canSubmit() ? '记下' : '先写点什么')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('app.color.okr_primary'))
        .fontColor($r('app.color.okr_on_primary'))
        .enabled(this.canSubmit())
        .onClick((): void => {
          this.submit();
        })
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
  }
}
