import { OkrProjectItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { PageShell, SectionCard } from '../components/PageShell';

interface ObjectiveRouteParam {
  objectiveId: string;
}

@ComponentV2
export struct ObjectiveDetailPage {
  @Local stack: NavPathStack = new NavPathStack();
  @Local objectiveId: string = '';
  @Local titleDraft: string = '';
  @Local periodDraft: string = '';
  @Local descDraft: string = '';
  @Local projectId: string = '';
  @Local projectPickerOpen: boolean = false;

  private projects(): OkrProjectItem[] {
    return OKR_STORE.projectList(true);
  }

  private projectLabel(): string {
    if (this.projectId.length === 0) {
      return '不关联项目';
    }
    const title: string = OKR_STORE.projectTitle(this.projectId);
    return title.length > 0 ? title : '不关联项目';
  }

  private commit(): void {
    if (this.titleDraft.trim().length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '目标名不能为空' });
      return;
    }
    const found = OKR_STORE.findObjective(this.objectiveId);
    if (found === undefined) {
      return;
    }
    OKR_STORE.updateObjective({
      id: this.objectiveId,
      title: this.titleDraft.trim(),
      period: this.periodDraft.trim(),
      desc: this.descDraft.trim(),
      projectId: this.projectId,
      createdAt: found.createdAt,
      updatedAt: found.updatedAt
    });
    this.getUIContext().getPromptAction().showToast({ message: '已保存' });
  }

  private delete(): void {
    AlertDialog.show({
      title: '删除目标',
      message: '目标下的 KR 与任务会一并删除，且无法恢复。',
      primaryButton: { value: '取消', action: (): void => {
      } },
      secondaryButton: { value: '删除', fontColor: $r('app.color.okr_danger'), action: (): void => {
        OKR_STORE.deleteObjective(this.objectiveId);
        this.stack.pop();
      } }
    });
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
      Text('目标详情')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('删除')
        .fontSize(14)
        .fontColor($r('app.color.okr_danger'))
        .onClick((): void => {
          this.delete();
        })
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      PageShell() {
        this.topBar()

        Column({ space: 14 }) {
          SectionCard({ cardTitle: '基本信息' }) {
            TextInput({ placeholder: '目标名称', text: this.titleDraft })
              .height(42)
              .fontSize(14)
              .backgroundColor($r('app.color.okr_bg'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.titleDraft = value;
              })
            TextInput({ placeholder: '周期，例如「本季度」（选填）', text: this.periodDraft })
              .height(42)
              .fontSize(14)
              .backgroundColor($r('app.color.okr_bg'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.periodDraft = value;
              })
            TextArea({ placeholder: '目标描述（选填）', text: this.descDraft })
              .height(80)
              .fontSize(13)
              .backgroundColor($r('app.color.okr_bg'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.descDraft = value;
              })
          }

          SectionCard({ cardTitle: '归属项目', cardHint: '把目标挂到项目下' }) {
            Text(this.projectLabel())
              .fontSize(13)
              .fontColor($r('app.color.okr_text_secondary'))
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.okr_bg'))
              .borderRadius(10)
              .onClick((): void => {
                this.projectPickerOpen = !this.projectPickerOpen;
              })

            if (this.projectPickerOpen) {
              Column({ space: 6 }) {
                Text('不关联项目')
                  .fontSize(13)
                  .fontColor($r('app.color.okr_text_primary'))
                  .width('100%')
                  .padding(10)
                  .onClick((): void => {
                    this.projectId = '';
                    this.projectPickerOpen = false;
                  })
                ForEach(this.projects(), (item: OkrProjectItem) => {
                  Text(item.title)
                    .fontSize(13)
                    .fontColor($r('app.color.okr_text_primary'))
                    .width('100%')
                    .padding(10)
                    .onClick((): void => {
                      this.projectId = item.id;
                      this.projectPickerOpen = false;
                    })
                }, (item: OkrProjectItem): string => item.id)
              }
              .width('100%')
              .padding(8)
              .backgroundColor($r('app.color.okr_card'))
              .borderRadius(10)
              .alignItems(HorizontalAlign.Start)
            }

          }

          Button('保存修改')
            .width('100%')
            .height(46)
            .fontSize(15)
            .backgroundColor($r('app.color.okr_primary'))
            .fontColor($r('app.color.okr_on_primary'))
            .onClick((): void => {
              this.commit();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.okr_bg'))
    .onReady((context: NavDestinationContext): void => {
      this.stack = context.pathStack;
      const param: ObjectiveRouteParam = context.pathInfo.param as ObjectiveRouteParam;
      if (param === null || param === undefined) {
        return;
      }
      const found = OKR_STORE.findObjective(param.objectiveId);
      if (found === undefined) {
        return;
      }
      this.objectiveId = param.objectiveId;
      this.titleDraft = found.title;
      this.periodDraft = found.period;
      this.descDraft = found.desc;
      this.projectId = found.projectId;
    })
    .onWillHide((): void => {
      this.commit();
    })
  }
}

@Builder
export function ObjectiveDetailBuilder() {
  ObjectiveDetailPage()
}
