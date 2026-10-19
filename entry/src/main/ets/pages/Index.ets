import { BusinessError } from '@kit.BasicServicesKit';
import { IdeaCard } from '../components/IdeaCard';
import { LoginPanel } from '../components/LoginPanel';
import { OkrEmptyHint } from '../components/OkrCommon';
import { ObjectiveCard } from '../components/ObjectiveCard';
import { QuickCapture } from '../components/QuickCapture';
import { TagFilterBar } from '../components/TagFilterBar';
import {
  OkrIdeaItem,
  OkrIdeaParam,
  OkrKrParam,
  OkrObjectiveItem,
  OkrObjectiveParam,
  OkrProjectItem,
  OkrProjectParam,
  okrHashTag
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { SESSION } from '../store/SessionStore';
import { SYNC } from '../store/SyncService';
import { ProjectCard } from '../components/ProjectCard';
import { PageShell } from '../components/PageShell';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local currentTab: number = 0;
  @Local objectiveComposerOpen: boolean = false;
  @Local objTitle: string = '';
  @Local objPeriod: string = '';
  @Local objDesc: string = '';
  @Local projectComposerOpen: boolean = false;
  @Local projTitle: string = '';
  @Local projDesc: string = '';
  @Local captureOpen: boolean = false;

  private visibleIdeas(): OkrIdeaItem[] {
    return OKR_STORE.visibleIdeas();
  }

  private objectiveList(): OkrObjectiveItem[] {
    return OKR_STORE.objectives;
  }

  private projectList(): OkrProjectItem[] {
    return OKR_STORE.projectList(false);
  }

  private toggleProjectComposer(): void {
    this.projectComposerOpen = !this.projectComposerOpen;
    this.projTitle = '';
    this.projDesc = '';
  }

  private createProject(): void {
    if (this.projTitle.trim().length === 0) {
      return;
    }
    OKR_STORE.addProject(this.projTitle.trim(), this.projDesc.trim(), okrHashTag(this.projTitle.trim()));
    this.projectComposerOpen = false;
    this.projTitle = '';
    this.projDesc = '';
  }

  @Builder
  projectComposer() {
    Column({ space: 8 }) {
      TextInput({ placeholder: '项目名称，例如「写作项目」', text: this.projTitle })
        .height(40)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_bg'))
        .borderRadius(8)
        .onChange((value: string): void => {
          this.projTitle = value;
        })
      TextInput({ placeholder: '项目描述（选填）', text: this.projDesc })
        .height(40)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_bg'))
        .borderRadius(8)
        .onChange((value: string): void => {
          this.projDesc = value;
        })
      Button('创建项目')
        .width(88)
        .height(40)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_project'))
        .fontColor($r('app.color.okr_on_primary'))
        .onClick((): void => {
          this.createProject();
        })
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
  }

  private headerSub(): string {
    return `待办 ${OKR_STORE.todoCount()} 条 · 今日完成 ${OKR_STORE.doneTodayCount()} 条`;
  }

  private openIdea(ideaId: string): void {
    const param: OkrIdeaParam = { ideaId: ideaId };
    this.pathStack.pushDestination({ name: 'IdeaDetail', param: param })
      .catch((error: BusinessError): void => {
        console.error(`open idea failed: ${error.message}`);
      });
  }

  private openKr(krId: string): void {
    const param: OkrKrParam = { objectiveId: OKR_STORE.krObjectiveId(krId), krId: krId };
    this.pathStack.pushDestination({ name: 'KrDetail', param: param })
      .catch((error: BusinessError): void => {
        console.error(`open kr failed: ${error.message}`);
      });
  }

  private openProject(projectId: string): void {
    const param: OkrProjectParam = { projectId: projectId };
    this.pathStack.pushDestination({ name: 'ProjectDetail', param: param })
      .catch((error: BusinessError): void => {
        console.error(`open project failed: ${error.message}`);
      });
  }

  private openObjective(objectiveId: string): void {
    const param: OkrObjectiveParam = { objectiveId: objectiveId };
    this.pathStack.pushDestination({ name: 'ObjectiveDetail', param: param })
      .catch((error: BusinessError): void => {
        console.error(`open objective failed: ${error.message}`);
      });
  }

  private openTagManage(): void {
    this.pathStack.pushDestination({ name: 'TagManage' })
      .catch((error: BusinessError): void => {
        console.error(`open tag manage failed: ${error.message}`);
      });
  }

  private openSettings(): void {
    this.pathStack.pushDestination({ name: 'Settings' })
      .catch((error: BusinessError): void => {
        console.error(`open settings failed: ${error.message}`);
      });
  }

  private toggleObjectiveComposer(): void {
    this.objectiveComposerOpen = !this.objectiveComposerOpen;
    this.objTitle = '';
    this.objPeriod = '';
    this.objDesc = '';
  }

  private createObjective(): void {
    if (this.objTitle.trim().length === 0) {
      return;
    }
    OKR_STORE.addObjective(this.objTitle.trim(), this.objPeriod.trim(), this.objDesc.trim());
    this.objectiveComposerOpen = false;
    this.objTitle = '';
    this.objPeriod = '';
    this.objDesc = '';
  }

  @Builder
  homeHeader() {
    Row() {
      Column({ space: 3 }) {
        Text('OKR 记事本')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))
        Text(this.headerSub())
          .fontSize(12)
          .fontColor($r('app.color.okr_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(SYNC.statusText())
        .fontSize(11)
        .fontColor($r('app.color.okr_text_tertiary'))
        .onClick((): void => {
          SYNC.syncNow();
        })

      Text('标签')
        .fontSize(12)
        .fontColor($r('app.color.okr_primary'))
        .margin({ right: 12 })
        .onClick((): void => {
          this.openTagManage();
        })

      Text('设置')
        .fontSize(12)
        .fontColor($r('app.color.okr_primary'))
        .onClick((): void => {
          this.openSettings();
        })
    }
    .width('100%')
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  inboxTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      List({ space: 10 }) {
        ListItem() {
          TagFilterBar()
        }

      if (this.visibleIdeas().length === 0) {
        ListItem() {
          OkrEmptyHint({
            hintText: OKR_STORE.activeTag.length > 0 ? '该标签下还没有内容' : '收件箱是空的',
            subText: OKR_STORE.activeTag.length > 0 ? '换个标签看看' : '在上方输入框写下第一个想法'
          })
        }
      } else {
        ForEach(this.visibleIdeas(), (ideaItem: OkrIdeaItem): void => {
          ListItem() {
            IdeaCard({
              ideaId: ideaItem.id,
              onOpen: (id: string): void => {
                this.openIdea(id);
              }
            })
          }
        }, (ideaItem: OkrIdeaItem): string => ideaItem.id)
      }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)

      Button('＋')
        .width(56)
        .height(56)
        .fontSize(28)
        .borderRadius(28)
        .opacity(0.85)
        .backgroundColor($r('app.color.okr_primary'))
        .fontColor($r('app.color.okr_on_primary'))
        .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 4 })
        .margin({ right: 20, bottom: 24 })
        .onClick((): void => {
          this.captureOpen = true;
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  captureSheet() {
    Column({ space: 10 }) {
      Text('快速记录')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .width('100%')

      QuickCapture({
        onDone: (): void => {
          this.captureOpen = false;
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_bg'))
  }

  @Builder
  goalComposer() {
    Column({ space: 8 }) {
      TextInput({ placeholder: '目标，例如「打造个人 OKR 闭环」', text: this.objTitle })
        .height(40)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_bg'))
        .borderRadius(8)
        .onChange((value: string): void => {
          this.objTitle = value;
        })
      Row({ space: 8 }) {
        TextArea({ placeholder: '目标描述（选填）', text: this.objDesc })
        .height(56)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_bg'))
        .borderRadius(8)
        .onChange((value: string): void => {
          this.objDesc = value;
        })
      TextInput({ placeholder: '周期（选填）', text: this.objPeriod })
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor($r('app.color.okr_bg'))
          .borderRadius(8)
          .onChange((value: string): void => {
            this.objPeriod = value;
          })
        Button('创建')
          .width(80)
          .height(40)
          .fontSize(13)
          .backgroundColor($r('app.color.okr_primary'))
          .fontColor($r('app.color.okr_on_primary'))
          .onClick((): void => {
            this.createObjective();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
  }

  @Builder
  fab(icon: string, active: boolean, tint: ResourceColor, onTap: () => void) {
    Button(icon)
      .width(56)
      .height(56)
      .fontSize(28)
      .borderRadius(28)
      .backgroundColor(active ? $r('app.color.okr_track') : tint)
      .fontColor(active ? $r('app.color.okr_text_secondary') : $r('app.color.okr_on_primary'))
      .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 4 })
      .margin({ right: 20, bottom: 20 })
      .onClick((): void => {
        onTap();
      })
  }

  @Builder
  goalsTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 12 }) {
        Text('目标与关键结果')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))
          .width('100%')

        if (this.objectiveComposerOpen) {
          this.goalComposer()
        }

        if (this.objectiveList().length === 0) {
          List() {
            ListItem() {
              OkrEmptyHint({
                hintText: '还没有目标',
                subText: '点右下角的加号开始设定'
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else {
          List({ space: 12 }) {
            ForEach(this.objectiveList(), (objItem: OkrObjectiveItem) => {
              ListItem() {
                ObjectiveCard({
                  objectiveId: objItem.id,
                  onOpenKr: (id: string): void => {
                    this.openKr(id);
                  },
                  onEdit: (id: string): void => {
                    this.openObjective(id);
                  }
                })
              }
            }, (objItem: OkrObjectiveItem): string => objItem.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: 24 })

      this.fab(this.objectiveComposerOpen ? '－' : '＋', this.objectiveComposerOpen,
        $r('app.color.okr_primary'), (): void => {
          this.toggleObjectiveComposer();
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  projectsTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 12 }) {
        Text('项目')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))
          .width('100%')

        if (this.projectComposerOpen) {
          this.projectComposer()
        }

        if (this.projectList().length === 0) {
          List() {
            ListItem() {
              OkrEmptyHint({
                hintText: '还没有项目',
                subText: '点右下角的加号，把目标、KR、任务串成一条线'
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else {
          List({ space: 12 }) {
            ForEach(this.projectList(), (projItem: OkrProjectItem) => {
              ListItem() {
                ProjectCard({
                  projectId: projItem.id,
                  onOpen: (id: string): void => {
                    this.openProject(id);
                  }
                })
              }
            }, (projItem: OkrProjectItem): string => projItem.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: 24 })

      this.fab(this.projectComposerOpen ? '－' : '＋', this.projectComposerOpen,
        $r('app.color.okr_project'), (): void => {
          this.toggleProjectComposer();
        })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Navigation(this.pathStack) {
      PageShell() {
        if (SESSION.isLoggedIn()) {
          Column({ space: 12 }) {
            this.homeHeader()
            Tabs({ index: this.currentTab }) {
              TabContent() {
                this.inboxTab()
              }
              .tabBar('收件箱')

              TabContent() {
                this.goalsTab()
              }
              .tabBar('目标')

              TabContent() {
                this.projectsTab()
              }
              .tabBar('项目')
            }
            .barMode(BarMode.Fixed)
            .barPosition(BarPosition.End)
            .barHeight(56)
            .divider({ strokeWidth: 1, color: $r('app.color.okr_divider') })
            .backgroundColor($r('app.color.okr_bg'))
            .onChange((index: number): void => {
              this.currentTab = index;
            })
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, top: 12 })
          .backgroundColor($r('app.color.okr_bg'))
        } else {
          LoginPanel({
            onSignedIn: (): void => {
              SYNC.start();
            }
          })
        }
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.okr_bg'))
    .bindSheet($$this.captureOpen, this.captureSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true
    })
  }
}
