import { BusinessError } from '@kit.BasicServicesKit';
import { LoginPanel } from '../components/LoginPanel';
import { OkrTabBar } from '../components/OkrTabBar';
import { QuickCapture } from '../components/QuickCapture';
import {
  OkrIdeaParam,
  OkrKrParam,
  OkrObjectiveParam,
  OkrProjectParam
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { SESSION } from '../store/SessionStore';
import { SYNC } from '../store/SyncService';
import { GoalsPage } from '../tabs/GoalsPage';
import { InsightsPage } from '../tabs/InsightsPage';
import { ProjectsPage } from '../tabs/ProjectsPage';
import { TodayPage } from '../tabs/TodayPage';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local currentTab: number = 0;
  @Local captureOpen: boolean = false;
  @Local objectiveComposerOpen: boolean = false;
  @Local objTitle: string = '';
  @Local objDesc: string = '';
  @Local objStart: string = '';
  @Local objEnd: string = '';

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
    this.objDesc = '';
    this.objStart = '';
    this.objEnd = '';
  }

  private createObjective(): void {
    if (this.objTitle.trim().length === 0) {
      return;
    }
    const start: number = this.parseDate(this.objStart);
    const end: number = this.parseDate(this.objEnd);
    OKR_STORE.addObjectiveWithSpan(this.objTitle.trim(), this.objDesc.trim(), start, end);
    this.objectiveComposerOpen = false;
  }

  private parseDate(text: string): number {
    const parts: string[] = text.split('-');
    if (parts.length !== 3) {
      return 0;
    }
    const year: number = Number(parts[0]);
    const month: number = Number(parts[1]);
    const day: number = Number(parts[2]);
    if (isNaN(year) || isNaN(month) || isNaN(day) || month < 1 || month > 12 || day < 1 || day > 31) {
      return 0;
    }
    return new Date(year, month - 1, day).getTime();
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
        autoFocus: this.captureOpen,
        onDone: (): void => {
          this.captureOpen = false;
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 4, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_bg'))
  }

  @Builder
  objectiveSheet() {
    Column({ space: 10 }) {
      Text('新建目标')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .width('100%')

      TextInput({ placeholder: '目标，例如「上线个人版 MVP」', text: this.objTitle })
        .height(42)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_track'))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.objTitle = value;
        })

      TextArea({ placeholder: '为什么重要（选填）', text: this.objDesc })
        .height(72)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_track'))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.objDesc = value;
        })

      Row({ space: 10 }) {
        TextInput({ placeholder: '开始 2026-10-01', text: this.objStart })
          .layoutWeight(1)
          .height(42)
          .fontSize(13)
          .backgroundColor($r('app.color.okr_track'))
          .borderRadius(10)
          .onChange((value: string): void => {
            this.objStart = value;
          })

        TextInput({ placeholder: '结束 2026-12-31', text: this.objEnd })
          .layoutWeight(1)
          .height(42)
          .fontSize(13)
          .backgroundColor($r('app.color.okr_track'))
          .borderRadius(10)
          .onChange((value: string): void => {
            this.objEnd = value;
          })
      }
      .width('100%')

      Row() {
        Blank()
        Button('创建')
          .height(38)
          .padding({ left: 20, right: 20 })
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .borderRadius(10)
          .backgroundColor($r('app.color.okr_text_primary'))
          .fontColor($r('app.color.okr_on_primary'))
          .onClick((): void => {
            this.createObjective();
          })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 4, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_bg'))
  }

  @Builder
  todayView() {
    TodayPage({
      onOpenKr: (krId: string): void => {
        this.openKr(krId);
      },
      onOpenObjective: (objectiveId: string): void => {
        this.openObjective(objectiveId);
      },
      onQuickAdd: (): void => {
        this.captureOpen = true;
      }
    })
  }

  @Builder
  goalsView() {
    GoalsPage({
      onOpenKr: (krId: string): void => {
        this.openKr(krId);
      },
      onOpenObjective: (objectiveId: string): void => {
        this.openObjective(objectiveId);
      },
      onCompose: (): void => {
        this.toggleObjectiveComposer();
      }
    })
  }

  @Builder
  projectsView() {
    ProjectsPage({
      onOpenProject: (projectId: string): void => {
        this.openProject(projectId);
      }
    })
  }

  @Builder
  insightsView() {
    InsightsPage({
      onOpenKr: (krId: string): void => {
        this.openKr(krId);
      }
    })
  }

  @Builder
  topActions() {
    Row({ space: 16 }) {
      Text('标签')
        .fontSize(12)
        .fontColor($r('app.color.okr_text_secondary'))
        .onClick((): void => {
          this.openTagManage();
        })
      Text('设置')
        .fontSize(12)
        .fontColor($r('app.color.okr_text_secondary'))
        .onClick((): void => {
          this.openSettings();
        })
    }
    .padding({ top: 6, bottom: 6, left: 4, right: 4 })
  }

  @Builder
  currentView() {
    if (this.currentTab === 0) {
      this.todayView()
    } else if (this.currentTab === 1) {
      this.goalsView()
    } else if (this.currentTab === 2) {
      this.projectsView()
    } else {
      this.insightsView()
    }
  }

  build() {
    Navigation(this.pathStack) {
      if (SESSION.isLoggedIn()) {
        Column() {
          Row() {
            Text(SYNC.statusText())
              .fontSize(10)
              .letterSpacing(1)
              .fontColor($r('app.color.okr_text_tertiary'))
            Blank()
            this.topActions()
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 8, bottom: 2 })

          // 各页自身是 height('100%')，必须用 layoutWeight 限高，否则会把标签栏挤出可视区
          Column() {
            this.currentView()
          }
          .width('100%')
          .layoutWeight(1)

          OkrTabBar({
            activeIndex: this.currentTab,
            onChange: (index: number): void => {
              this.currentTab = index;
            }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.okr_bg'))
      } else {
        LoginPanel({
          onSignedIn: (): void => {
            SYNC.start();
          }
        })
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.okr_bg'))
    .bindSheet($$this.captureOpen, this.captureSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE
    })
    .bindSheet($$this.objectiveComposerOpen, this.objectiveSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE
    })
  }
}
