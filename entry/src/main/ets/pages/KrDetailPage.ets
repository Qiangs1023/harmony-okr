import {
  OkrIdeaItem,
  OkrIdeaParam,
  OkrKrItem,
  OkrKrParam,
  OkrObjectiveItem,
  okrDueText,
  okrFormatDate
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { IdeaCard } from '../components/IdeaCard';
import { OkrEmptyHint, OkrProgressTrack } from '../components/OkrCommon';

@ComponentV2
struct KrDetailPage {
  @Local stack: NavPathStack = new NavPathStack();
  @Local krId: string = '';
  @Local dirty: boolean = false;
  @Local titleDraft: string = '';
  @Local targetDraft: string = '';
  @Local due: number = 0;
  @Local newIdeaText: string = '';
  @Local pickerOpen: boolean = false;

  private kr(): OkrKrItem | undefined {
    return OKR_STORE.findKr(this.krId);
  }

  private titleText(): string {
    const found: OkrKrItem | undefined = this.kr();
    return found === undefined ? '' : found.title;
  }

  private targetText(): string {
    const found: OkrKrItem | undefined = this.kr();
    if (found === undefined || found.targetValue.length === 0) {
      return '未设置衡量指标';
    }
    return found.targetValue;
  }

  private dueText(): string {
    const found: OkrKrItem | undefined = this.kr();
    if (found === undefined || found.dueDate <= 0) {
      return '无截止日期';
    }
    return okrDueText(found.dueDate);
  }

  private objectiveName(): string {
    const found: OkrKrItem | undefined = this.kr();
    if (found === undefined) {
      return '';
    }
    const obj: OkrObjectiveItem | undefined = OKR_STORE.findObjective(found.objectiveId);
    return obj === undefined ? '' : obj.title;
  }

  private dueLabel(): string {
    if (this.due <= 0) {
      return '设置截止日期';
    }
    return okrFormatDate(this.due);
  }

  private linkedIdeas(): OkrIdeaItem[] {
    return OKR_STORE.ideasOfKr(this.krId);
  }

  private unlinkedIdeas(): OkrIdeaItem[] {
    return OKR_STORE.ideas.filter((item: OkrIdeaItem): boolean => item.krId !== this.krId);
  }

  private load(krId: string): void {
    const found: OkrKrItem | undefined = OKR_STORE.findKr(krId);
    if (found === undefined) {
      return;
    }
    this.krId = krId;
    this.titleDraft = found.title;
    this.targetDraft = found.targetValue;
    this.due = found.dueDate;
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

  private save(): void {
    const found: OkrKrItem | undefined = this.kr();
    if (found === undefined) {
      return;
    }
    const draft: OkrKrItem = {
      id: found.id,
      objectiveId: found.objectiveId,
      title: this.titleDraft.trim().length > 0 ? this.titleDraft.trim() : found.title,
      targetValue: this.targetDraft.trim(),
      dueDate: this.due,
      createdAt: found.createdAt,
      updatedAt: found.updatedAt
    };
    OKR_STORE.updateKr(draft);
    this.dirty = false;
  }

  private goBack(): void {
    if (this.dirty) {
      this.save();
    }
    this.stack.pop();
  }

  private addIdea(): void {
    if (this.newIdeaText.trim().length === 0) {
      return;
    }
    const created: OkrIdeaItem = OKR_STORE.addIdea(this.newIdeaText, 1, 0);
    OKR_STORE.linkIdeaToKr(created.id, this.krId);
    this.newIdeaText = '';
    this.pickerOpen = false;
  }

  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: '删除这个关键结果？',
      message: '已关联的想法会回到收件箱，不会被删除',
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.okr_danger'),
        action: (): void => {
          OKR_STORE.deleteKr(this.krId);
          this.stack.pop();
        }
      }
    });
  }

  private openIdea(ideaId: string): void {
    const param: OkrIdeaParam = { ideaId: ideaId };
    this.stack.pushDestination({ name: 'IdeaDetail', param: param });
  }

  @Builder
  topBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(15)
        .fontColor($r('app.color.okr_text_primary'))
        .height(36)
        .padding({ right: 12 })
        .textAlign(TextAlign.Center)
        .onClick((): void => {
          this.goBack();
        })
      Text('关键结果')
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

  @Builder
  sectionLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.okr_text_secondary'))
  }

  @Builder
  linkPicker() {
    Column({ space: 4 }) {
      if (this.unlinkedIdeas().length === 0) {
        Text('所有想法都已经关联过了')
          .fontSize(12)
          .fontColor($r('app.color.okr_text_tertiary'))
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(this.unlinkedIdeas(), (ideaItem: OkrIdeaItem) => {
          Row() {
            Text(ideaItem.title)
              .fontSize(13)
              .fontColor($r('app.color.okr_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('关联')
              .fontSize(12)
              .fontColor($r('app.color.okr_primary'))
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .onClick((): void => {
            OKR_STORE.linkIdeaToKr(ideaItem.id, this.krId);
          })
        }, (ideaItem: OkrIdeaItem): string => ideaItem.id)
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
            Column({ space: 6 }) {
              this.sectionLabel('所属目标')
              Text(this.objectiveName())
                .fontSize(13)
                .fontColor($r('app.color.okr_text_secondary'))
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              this.sectionLabel('关键结果')
              TextInput({ placeholder: '例如「连续记录 30 天」', text: this.titleDraft })
                .height(42)
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

            Column({ space: 6 }) {
              this.sectionLabel('衡量指标')
              TextInput({ placeholder: '例如「30 篇复盘」', text: this.targetDraft })
                .height(42)
                .fontSize(14)
                .backgroundColor($r('app.color.okr_bg'))
                .borderRadius(12)
                .onChange((value: string): void => {
                  this.targetDraft = value;
                  this.dirty = true;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

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
              Text(this.dueText())
                .height(38)
                .fontSize(12)
                .fontColor($r('app.color.okr_text_secondary'))
                .padding({ left: 4 })
              Text('保存')
                .height(38)
                .fontSize(13)
                .fontColor($r('app.color.okr_primary'))
                .padding({ left: 12 })
                .textAlign(TextAlign.Center)
                .onClick((): void => {
                  this.save();
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Column({ space: 8 }) {
              Row() {
                Text(`进度 ${OKR_STORE.krProgress(this.krId)}%`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.okr_text_primary'))
                  .layoutWeight(1)
                Text(this.targetText())
                  .fontSize(12)
                  .fontColor($r('app.color.okr_text_secondary'))
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              OkrProgressTrack({ percent: OKR_STORE.krProgress(this.krId), barColor: $r('app.color.okr_primary') })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 10 }) {
              Row() {
                this.sectionLabel('关联任务')
                Blank()
                Text('＋ 新建')
                  .fontSize(12)
                  .fontColor($r('app.color.okr_primary'))
                  .height(26)
                  .padding({ left: 10 })
                  .textAlign(TextAlign.Center)
                  .onClick((): void => {
                    this.pickerOpen = !this.pickerOpen;
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              if (this.pickerOpen) {
                Column({ space: 8 }) {
                  TextInput({ placeholder: '新想法，用 #标签 归类', text: this.newIdeaText })
                    .height(40)
                    .fontSize(13)
                    .backgroundColor($r('app.color.okr_bg'))
                    .borderRadius(10)
                    .onChange((value: string): void => {
                      this.newIdeaText = value;
                    })
                  Button('创建并关联')
                    .width('100%')
                    .height(36)
                    .fontSize(13)
                    .backgroundColor($r('app.color.okr_primary'))
                    .fontColor('#FFFFFF')
                    .onClick((): void => {
                      this.addIdea();
                    })
                  Button('从收件箱选择')
                    .width('100%')
                    .height(36)
                    .fontSize(13)
                    .backgroundColor($r('app.color.okr_track'))
                    .fontColor($r('app.color.okr_text_secondary'))
                    .onClick((): void => {
                      this.pickerOpen = true;
                    })
                  if (this.unlinkedIdeas().length > 0) {
                    this.linkPicker()
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              if (this.linkedIdeas().length === 0) {
                OkrEmptyHint({
                  hintText: '还没有关联任务',
                  subText: '点右上角「＋ 新建」把想法挂到这个 KR'
                })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.linkedIdeas(), (ideaItem: OkrIdeaItem) => {
                    IdeaCard({
                      ideaId: ideaItem.id,
                      onOpen: (id: string): void => {
                        this.openIdea(id);
                      }
                    })
                  }, (ideaItem: OkrIdeaItem): string => ideaItem.id)
                }
                .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
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
      const param: OkrKrParam = context.pathInfo.param as OkrKrParam;
      if (param !== undefined && param !== null) {
        this.load(param.krId);
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
export function KrDetailBuilder() {
  KrDetailPage()
}
