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
import { PageShell, SectionCard } from '../components/PageShell';
import { OkrEmptyHint } from '../components/OkrCommon';
import { OkrLedgerLine, OkrMeter } from '../components/OkrUi';
import { TaskRow } from '../tabs/TodayPage';
import { OkrFlowState, okrFlowLabel } from '../model/OkrAnalytics';

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
      projectId: found.projectId,
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
    .backgroundColor($r('app.color.okr_track'))
    .borderRadius(12)
  }

  build() {
    NavDestination() {
      PageShell() {
        Column({ space: 14 }) {
          this.topBar()

          Scroll() {
            Column({ space: 12 }) {
              SectionCard({ cardTitle: '基本信息', cardHint: this.objectiveName() }) {
                TextInput({ placeholder: '关键结果，例如「连续记录 30 天」', text: this.titleDraft })
                  .height(42)
                  .fontSize(15)
                  .backgroundColor($r('app.color.okr_track'))
                  .borderRadius(12)
                  .onChange((value: string): void => {
                    this.titleDraft = value;
                    this.dirty = true;
                  })
                TextInput({ placeholder: '衡量指标，例如「30 篇复盘」', text: this.targetDraft })
                  .height(42)
                  .fontSize(14)
                  .backgroundColor($r('app.color.okr_track'))
                  .borderRadius(12)
                  .onChange((value: string): void => {
                    this.targetDraft = value;
                    this.dirty = true;
                  })
              }

              SectionCard({ cardTitle: '截止与进度' }) {
                Row({ space: 8 }) {
                  Button(this.dueLabel())
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(13)
                    .borderRadius(10)
                    .backgroundColor($r('app.color.okr_track'))
                    .fontColor($r('app.color.okr_text_primary'))
                    .onClick((): void => {
                      this.pickDate();
                    })
                  Text(this.dueText())
                    .height(38)
                    .fontSize(12)
                    .fontColor($r('app.color.okr_text_secondary'))
                    .padding({ left: 4 })
                  Button('保存')
                    .height(38)
                    .padding({ left: 16, right: 16 })
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .borderRadius(10)
                    .backgroundColor($r('app.color.okr_text_primary'))
                    .fontColor($r('app.color.okr_on_primary'))
                    .onClick((): void => {
                      this.save();
                    })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Row() {
                  Text('进度')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.okr_text_secondary'))
                  Blank()
                  Text(`${OKR_STORE.krProgress(this.krId)}%`)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .letterSpacing(-0.4)
                    .fontColor($r('app.color.okr_text_primary'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Bottom)

                OkrMeter({
                  actual: OKR_STORE.krProgress(this.krId),
                  expected: OKR_STORE.krExpected(this.krId),
                  state: OKR_STORE.krState(this.krId)
                })
                .margin({ top: 12 })

                OkrLedgerLine({
                  leftText: `${okrFlowLabel(OKR_STORE.krState(this.krId), OKR_STORE.krProgress(this.krId), OKR_STORE.krExpected(this.krId))} · ${this.linkedIdeas().length} 个任务`,
                  rightText: this.targetText(),
                  tone: OKR_STORE.krState(this.krId)
                })
              }

              SectionCard({ cardTitle: '关联任务', cardHint: '把想法挂到这个 KR' }) {
                Row() {
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
                      .backgroundColor($r('app.color.okr_track'))
                      .borderRadius(10)
                      .onChange((value: string): void => {
                        this.newIdeaText = value;
                      })
                    Button('创建并关联')
                      .width('100%')
                      .height(36)
                      .fontSize(13)
                      .backgroundColor($r('app.color.okr_primary'))
                      .fontColor($r('app.color.okr_on_primary'))
                      .onClick((): void => {
                        this.addIdea();
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
                  Column() {
                    ForEach(this.linkedIdeas(), (ideaItem: OkrIdeaItem, index: number): void => {
                      if (index > 0) {
                        Divider()
                          .strokeWidth(1)
                          .color($r('app.color.okr_divider'))
                      }
                      TaskRow({
                        taskId: ideaItem.id,
                        krTitle: '',
                        krState: OKR_STORE.krState(this.krId)
                      })
                    }, (ideaItem: OkrIdeaItem): string => ideaItem.id)
                  }
                  .width('100%')
                }
              }
            }
            .width('100%')
            .padding({ bottom: 24 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
        Button('删除这个关键结果')
          .width('100%')
          .height(42)
          .fontSize(14)
          .borderRadius(10)
          .backgroundColor($r('app.color.okr_danger_soft'))
          .fontColor($r('app.color.okr_danger'))
          .margin({ top: 8 })
          .onClick((): void => {
            this.confirmDelete();
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 12 })
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.okr_track'))
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
