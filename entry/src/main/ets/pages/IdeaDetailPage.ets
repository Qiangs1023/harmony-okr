import { OkrSelectChip, OkrTagChip } from '../components/OkrCommon';
import {
  OkrIdeaItem,
  OkrIdeaParam,
  OkrKrItem,
  OkrObjectiveItem,
  OkrPriority,
  okrEmptyIdea,
  okrFormatDate,
  okrPriorityColor,
  okrPriorityLabel
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';

@ComponentV2
struct IdeaDetailPage {
  @Local stack: NavPathStack = new NavPathStack();
  @Local ideaId: string = '';
  @Local loaded: boolean = false;
  @Local dirty: boolean = false;
  @Local titleDraft: string = '';
  @Local noteDraft: string = '';
  @Local priority: number = OkrPriority.Medium;
  @Local due: number = 0;
  @Local krId: string = '';
  @Local projectId: string = '';
  @Local tagList: string[] = [];
  @Local tagInput: string = '';
  @Local krPickerOpen: boolean = false;

  private allKrs(): OkrKrItem[] {
    return OKR_STORE.krs;
  }

  private objectiveTitle(objectiveId: string): string {
    const obj: OkrObjectiveItem | undefined = OKR_STORE.findObjective(objectiveId);
    return obj === undefined ? '' : obj.title;
  }

  private krButtonLabel(): string {
    if (this.krPickerOpen) {
      return '收起';
    }
    if (this.krId.length > 0) {
      return OKR_STORE.krTitle(this.krId);
    }
    return '选择一个 KR';
  }

  private krButtonColor(): ResourceColor {
    if (this.krId.length > 0) {
      return $r('app.color.okr_primary');
    }
    return $r('app.color.okr_text_secondary');
  }

  private current(): OkrIdeaItem {
    const found: OkrIdeaItem | undefined = OKR_STORE.findIdea(this.ideaId);
    return found === undefined ? okrEmptyIdea() : found;
  }

  private levels(): number[] {
    return [OkrPriority.Low, OkrPriority.Medium, OkrPriority.High];
  }

  private isDone(): boolean {
    return this.current().done;
  }

  private dueLabel(): string {
    if (this.due <= 0) {
      return '设置截止日期';
    }
    return okrFormatDate(this.due);
  }

  private load(id: string): void {
    const found: OkrIdeaItem | undefined = OKR_STORE.findIdea(id);
    if (found === undefined) {
      return;
    }
    this.ideaId = id;
    this.titleDraft = found.title;
    this.noteDraft = found.note;
    this.priority = found.priority;
    this.due = found.dueDate;
    this.krId = found.krId;
    this.projectId = found.projectId;
    this.tagList = found.tags.slice();
    this.loaded = true;
    this.dirty = false;
  }

  private pickDate(): void {
    const base: Date = this.due > 0 ? new Date(this.due) : new Date();
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2035, 11, 31),
      selected: base,
      lunar: false,
      onAccept: (value: DatePickerResult): void => {
        const year: number = value.year ?? 2025;
        const month: number = value.month ?? 1;
        const day: number = value.day ?? 1;
        this.due = new Date(year, month - 1, day, 12, 0, 0).getTime();
        this.dirty = true;
      }
    });
  }

  private clearDate(): void {
    this.due = 0;
    this.dirty = true;
  }

  private addTag(): void {
    const name: string = this.tagInput.trim().replace(/^#/, '');
    if (name.length === 0) {
      return;
    }
    if (this.tagList.indexOf(name) < 0) {
      this.tagList = this.tagList.concat([name]);
      this.dirty = true;
    }
    this.tagInput = '';
  }

  private removeTag(name: string): void {
    const next: string[] = [];
    for (let i = 0; i < this.tagList.length; i++) {
      if (this.tagList[i] !== name) {
        next.push(this.tagList[i]);
      }
    }
    this.tagList = next;
    this.dirty = true;
  }

  private toggleDone(): void {
    OKR_STORE.toggleIdeaDone(this.ideaId);
  }

  private save(): void {
    const base: OkrIdeaItem = this.current();
    const draft: OkrIdeaItem = {
      id: base.id,
      title: this.titleDraft.trim().length > 0 ? this.titleDraft.trim() : base.title,
      note: this.noteDraft,
      tags: this.tagList,
      priority: this.priority,
      dueDate: this.due,
      krId: this.krId,
      projectId: this.projectId,
      done: base.done,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt
    };
    OKR_STORE.saveIdea(draft);
    this.dirty = false;
    this.getUIContext().getPromptAction().showToast({ message: '已保存' });
  }

  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: '删除这条想法？',
      message: '删除后无法恢复',
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.okr_danger'),
        action: (): void => {
          OKR_STORE.deleteIdea(this.ideaId);
          this.stack.pop();
        }
      }
    });
  }

  private goBack(): void {
    if (this.dirty) {
      this.save();
    }
    this.stack.pop();
  }

  @Builder
  topBar() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor($r('app.color.okr_text_primary'))
        .width(32)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick((): void => {
          this.goBack();
        })
      Text('想法详情')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .layoutWeight(1)
      Text('删除')
        .fontSize(14)
        .fontColor($r('app.color.okr_danger'))
        .height(36)
        .padding({ left: 12, right: 4 })
        .textAlign(TextAlign.Center)
        .onClick((): void => {
          this.confirmDelete();
        })
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  private krStateColor(krId: string): ResourceColor {
    if (this.krId === krId) {
      return $r('app.color.okr_success');
    }
    return $r('app.color.okr_primary');
  }

  private krStateText(krId: string): string {
    if (this.krId === krId) {
      return '已关联';
    }
    return '关联';
  }

  @Builder
  sectionLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.okr_text_secondary'))
  }

  @Builder
  krPicker() {
    Column({ space: 6 }) {
      if (this.allKrs().length === 0) {
        Text('还没有任何关键结果')
          .fontSize(12)
          .fontColor($r('app.color.okr_text_tertiary'))
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(this.allKrs(), (krItem: OkrKrItem) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(krItem.title)
                .fontSize(13)
                .fontColor($r('app.color.okr_text_primary'))
              Text(this.objectiveTitle(krItem.objectiveId))
                .fontSize(11)
                .fontColor($r('app.color.okr_text_tertiary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(this.krStateText(krItem.id))
              .fontSize(12)
              .fontColor(this.krStateColor(krItem.id))
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .onClick((): void => {
            this.krId = this.krId === krItem.id ? '' : krItem.id;
            this.dirty = true;
          })
        }, (krItem: OkrKrItem): string => krItem.id)
      }
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_bg'))
    .borderRadius(12)
  }

  build() {
    NavDestination() {
      Column({ space: 14 }) {
        this.topBar()

        Scroll() {
          Column({ space: 16 }) {
            Row({ space: 10 }) {
              Checkbox({ name: 'detail_done', group: 'okr_detail' })
                .shape(CheckBoxShape.CIRCLE)
                .width(20)
                .height(20)
                .select(this.isDone())
                .selectedColor($r('app.color.okr_primary'))
                .onChange((checked: boolean): void => {
                  this.toggleDone();
                })
              Text(this.isDone() ? '已完成' : '标记为完成')
                .fontSize(13)
                .fontColor($r('app.color.okr_text_secondary'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Column({ space: 6 }) {
              this.sectionLabel('标题')
              TextArea({ placeholder: '这条想法是什么？', text: this.titleDraft })
                .height(84)
                .fontSize(15)
                .backgroundColor($r('app.color.okr_bg'))
                .borderRadius(12)
                .onChange((value: string): void => {
                  this.titleDraft = value;
                  this.dirty = true;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              this.sectionLabel('标签')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.tagList, (tagName: string) => {
                  Row({ space: 4 }) {
                    OkrTagChip({
                      chipText: tagName,
                      colorIndex: OKR_STORE.tagColorIndex(tagName),
                      solid: false
                    })
                    Text('✕')
                      .fontSize(11)
                      .fontColor($r('app.color.okr_text_secondary'))
                      .margin({ right: 6 })
                      .onClick((): void => {
                        this.removeTag(tagName);
                      })
                  }
                }, (tagName: string): string => tagName)
              }
              .width('100%')
              Row({ space: 8 }) {
                TextInput({ placeholder: '添加标签', text: this.tagInput })
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(13)
                  .borderRadius(19)
                  .backgroundColor($r('app.color.okr_bg'))
                  .onChange((value: string): void => {
                    this.tagInput = value;
                  })
                  .onSubmit((enterKey: EnterKeyType): void => {
                    this.addTag();
                  })
                Button('添加')
                  .height(38)
                  .fontSize(13)
                  .backgroundColor($r('app.color.okr_primary_soft'))
                  .fontColor($r('app.color.okr_primary'))
                  .onClick((): void => {
                    this.addTag();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              this.sectionLabel('优先级')
              Row({ space: 8 }) {
                ForEach(this.levels(), (level: number) => {
                  OkrSelectChip({
                    chipText: okrPriorityLabel(level),
                    active: this.priority === level,
                    chipColor: okrPriorityColor(level),
                    onPick: (): void => {
                      this.priority = level;
                      this.dirty = true;
                    }
                  })
                }, (level: number): string => `${level}`)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              this.sectionLabel('截止日期')
              Row({ space: 8 }) {
                Button(this.dueLabel())
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(13)
                  .backgroundColor($r('app.color.okr_bg'))
                  .fontColor($r('app.color.okr_text_primary'))
                  .onClick((): void => {
                    this.pickDate();
                  })
                Button('清除')
                  .height(38)
                  .fontSize(13)
                  .backgroundColor($r('app.color.okr_bg'))
                  .fontColor($r('app.color.okr_text_secondary'))
                  .onClick((): void => {
                    this.clearDate();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              this.sectionLabel('关联关键结果')
              Button(this.krButtonLabel())
                .width('100%')
                .height(38)
                .fontSize(13)
                .backgroundColor($r('app.color.okr_bg'))
                .fontColor(this.krButtonColor())
                .onClick((): void => {
                  this.krPickerOpen = !this.krPickerOpen;
                })
              if (this.krPickerOpen) {
                this.krPicker()
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              this.sectionLabel('备注')
              TextArea({ placeholder: '补充说明、上下文、后续动作…', text: this.noteDraft })
                .height(110)
                .fontSize(14)
                .backgroundColor($r('app.color.okr_bg'))
                .borderRadius(12)
                .onChange((value: string): void => {
                  this.noteDraft = value;
                  this.dirty = true;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Button('保存修改')
              .width('100%')
              .height(46)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('app.color.okr_primary'))
              .fontColor($r('app.color.okr_on_primary'))
              .onClick((): void => {
                this.save();
              })
          }
          .width('100%')
          .padding({ bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 12 })
      .backgroundColor($r('app.color.okr_bg'))
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.okr_bg'))
    .onReady((context: NavDestinationContext): void => {
      this.stack = context.pathStack;
      const param: OkrIdeaParam = context.pathInfo.param as OkrIdeaParam;
      if (param !== undefined && param !== null) {
        this.load(param.ideaId);
      }
    })
    .onWillHide((): void => {
      if (this.dirty) {
        this.save();
      }
    })
  }
}

@Builder
export function IdeaDetailBuilder() {
  IdeaDetailPage()
}
