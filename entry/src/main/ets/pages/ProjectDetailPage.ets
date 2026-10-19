import { BusinessError } from '@kit.BasicServicesKit';
import { okrTagColor, OkrIdeaItem, OkrKrItem, OkrObjectiveItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrFlowState } from '../model/OkrAnalytics';
import { OkrMeter } from '../components/OkrUi';
import { PageShell, SectionCard } from '../components/PageShell';
import { QuickCapture } from '../components/QuickCapture';

interface ProjectRouteParam {
  projectId: string;
}

@ComponentV2
export struct ProjectDetailPage {
  @Local stack: NavPathStack = new NavPathStack();
  @Local projectId: string = '';
  @Local titleDraft: string = '';
  @Local descDraft: string = '';
  @Local colorIndex: number = 0;
  @Local archived: boolean = false;
  @Local loaded: boolean = false;
  @Local taskSheetOpen: boolean = false;

  private commit(): void {
    if (this.titleDraft.trim().length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '项目名不能为空' });
      return;
    }
    const found = OKR_STORE.findProject(this.projectId);
    if (found === undefined) {
      return;
    }
    OKR_STORE.updateProject({
      id: this.projectId,
      title: this.titleDraft.trim(),
      desc: this.descDraft.trim(),
      colorIndex: this.colorIndex,
      archived: this.archived,
      createdAt: found.createdAt,
      updatedAt: found.updatedAt
    });
    this.getUIContext().getPromptAction().showToast({ message: '已保存' });
  }

  private delete(): void {
    AlertDialog.show({
      title: '删除项目',
      message: '项目下的目标、KR、任务不会被删除，只会解除关联。',
      primaryButton: { value: '取消', action: (): void => {
      } },
      secondaryButton: { value: '删除', fontColor: $r('app.color.okr_danger'), action: (): void => {
        OKR_STORE.deleteProject(this.projectId);
        this.stack.pop();
      } }
    });
  }

  private ideas(): OkrIdeaItem[] {
    return OKR_STORE.ideasOfProject(this.projectId);
  }

  private krs(): OkrKrItem[] {
    return OKR_STORE.krsOfProject(this.projectId);
  }

  private objectives(): OkrObjectiveItem[] {
    return OKR_STORE.objectivesOfProject(this.projectId);
  }

  private projectState(): OkrFlowState {
    let worst: OkrFlowState = OkrFlowState.OnTrack;
    const list: OkrKrItem[] = OKR_STORE.krsOfProject(this.projectId);
    for (let i = 0; i < list.length; i++) {
      const state: OkrFlowState = OKR_STORE.krState(list[i].id);
      if (state === OkrFlowState.Behind) {
        return OkrFlowState.Behind;
      }
      if (state === OkrFlowState.Stalled) {
        worst = OkrFlowState.Stalled;
      }
    }
    return worst;
  }

  private progress(): number {
    return OKR_STORE.projectProgress(this.projectId);
  }

  @Builder
  taskSheet() {
    Column({ space: 10 }) {
      Text('新建任务')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .width('100%')
      QuickCapture({
        autoFocus: this.taskSheetOpen,
        forceProjectId: this.projectId,
        onDone: (): void => {
          this.taskSheetOpen = false;
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_track'))
  }

  @Builder
  topBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(14)
        .fontColor($r('app.color.okr_primary'))
        .onClick((): void => {
          this.commit();
          this.stack.pop();
        })
      Text('项目详情')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank()
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      PageShell() {
        Column({ space: 14 }) {
          this.topBar()

          Scroll() {
            Column({ space: 12 }) {
          SectionCard({ cardTitle: '基本信息' }) {
            TextInput({ placeholder: '项目名称', text: this.titleDraft })
              .height(42)
              .fontSize(14)
              .backgroundColor($r('app.color.okr_track'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.titleDraft = value;
              })
            TextArea({ placeholder: '项目描述（选填）', text: this.descDraft })
              .height(72)
              .fontSize(13)
              .backgroundColor($r('app.color.okr_track'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.descDraft = value;
              })

            Scroll() {
              Row({ space: 8 }) {
                ForEach([0, 1, 2, 3, 4, 5, 6, 7], (index: number): void => {
                  Row()
                    .width(28)
                    .height(28)
                    .backgroundColor(okrTagColor(index))
                    .borderRadius(14)
                    .border({ width: this.colorIndex === index ? 2 : 0, color: $r('app.color.okr_text_primary') })
                    .onClick((): void => {
                      this.colorIndex = index;
                    })
                }, (index: number): string => `${index}`)
              }
            }
            .width('100%')
            .height(34)
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)

            Row() {
              Text(this.archived ? '项目已归档，点击恢复' : '归档项目')
                .fontSize(13)
                .fontColor($r('app.color.okr_text_secondary'))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.archived })
                .selectedColor($r('app.color.okr_primary'))
                .onChange((on: boolean): void => {
                  this.archived = on;
                })
            }
            .width('100%')
          }

          Button('保存修改')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.okr_primary'))
            .fontColor($r('app.color.okr_on_primary'))
            .onClick((): void => {
              this.commit();
            })

          Button('删除项目')
            .width('100%')
            .height(42)
            .fontSize(14)
            .backgroundColor($r('app.color.okr_card'))
            .fontColor($r('app.color.okr_danger'))
            .onClick((): void => {
              this.delete();
            })

          SectionCard({ cardTitle: '任务完成度', cardHint: `${this.progress()}%` }) {
            OkrMeter({
              actual: this.progress(),
              expected: OKR_STORE.projectExpected(this.projectId),
              state: this.projectState(),
              showLabel: false
            })
          }

          if (this.objectives().length > 0) {
            SectionCard({ cardTitle: `关联目标 ${this.objectives().length}` }) {
              ForEach(this.objectives(), (item: OkrObjectiveItem): void => {
                Column({ space: 3 }) {
                  Text(item.title)
                    .fontSize(13)
                    .fontColor($r('app.color.okr_text_primary'))
                  Text(item.period.length > 0 ? item.period : '未设周期')
                    .fontSize(11)
                    .fontColor($r('app.color.okr_text_tertiary'))
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.okr_track'))
                .borderRadius(10)
                .alignItems(HorizontalAlign.Start)
              }, (item: OkrObjectiveItem): string => item.id)
            }
          }

          if (this.krs().length > 0) {
            SectionCard({ cardTitle: `关联关键结果 ${this.krs().length}` }) {
              ForEach(this.krs(), (item: OkrKrItem): void => {
                Column({ space: 3 }) {
                  Text(item.title)
                    .fontSize(13)
                    .fontColor($r('app.color.okr_text_primary'))
                  Text(item.targetValue.length > 0 ? item.targetValue : '未设衡量指标')
                    .fontSize(11)
                    .fontColor($r('app.color.okr_text_tertiary'))
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.okr_track'))
                .borderRadius(10)
                .alignItems(HorizontalAlign.Start)
              }, (item: OkrKrItem): string => item.id)
            }
          }

          SectionCard({
            cardTitle: `关联任务 ${this.ideas().length}`,
            headerAction: '＋ 新建',
            onHeaderAction: (): void => {
              this.taskSheetOpen = true;
            }
          }) {
              ForEach(this.ideas(), (item: OkrIdeaItem): void => {
                Row({ space: 8 }) {
                  Text(item.title)
                    .fontSize(13)
                    .fontColor(item.done ? $r('app.color.okr_text_tertiary') : $r('app.color.okr_text_primary'))
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.done ? '已完成' : '进行中')
                    .fontSize(11)
                    .fontColor($r('app.color.okr_text_tertiary'))
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.okr_track'))
                .borderRadius(10)
              }, (item: OkrIdeaItem): string => item.id)
            }
        }
            .width('100%')
            .padding({ bottom: 24 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 12 })
        .bindSheet($$this.taskSheetOpen, this.taskSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: true,
          keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.okr_track'))
    .onReady((context: NavDestinationContext): void => {
      this.stack = context.pathStack;
      const param: ProjectRouteParam = context.pathInfo.param as ProjectRouteParam;
      if (param === null || param === undefined) {
        return;
      }
      const found = OKR_STORE.findProject(param.projectId);
      if (found === undefined) {
        return;
      }
      this.projectId = param.projectId;
      this.titleDraft = found.title;
      this.descDraft = found.desc;
      this.colorIndex = found.colorIndex;
      this.archived = found.archived;
      this.loaded = true;
    })
  }
}

@Builder
export function ProjectDetailBuilder() {
  ProjectDetailPage()
}
