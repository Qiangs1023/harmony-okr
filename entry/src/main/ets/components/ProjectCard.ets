import { okrTagColor } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';

@ComponentV2
export struct ProjectCard {
  @Param projectId: string = '';
  @Event onOpen: (projectId: string) => void = (projectId: string): void => {
  };

  private title(): string {
    return OKR_STORE.projectTitle(this.projectId);
  }

  private desc(): string {
    const found = OKR_STORE.findProject(this.projectId);
    return found === undefined ? '' : found.desc;
  }

  private colorIndex(): number {
    const found = OKR_STORE.findProject(this.projectId);
    return found === undefined ? 0 : found.colorIndex;
  }

  private ideaCount(): number {
    return OKR_STORE.ideasOfProject(this.projectId).length;
  }

  private krCount(): number {
    return OKR_STORE.krsOfProject(this.projectId).length;
  }

  private objectiveCount(): number {
    return OKR_STORE.objectivesOfProject(this.projectId).length;
  }

  build() {
    Row({ space: 12 }) {
      Row()
        .width(4)
        .height(52)
        .backgroundColor(okrTagColor(this.colorIndex()))
        .borderRadius(2)

      Column({ space: 6 }) {
        Text(this.title())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.desc().length > 0) {
          Text(this.desc())
            .fontSize(12)
            .fontColor($r('app.color.okr_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row({ space: 6 }) {
          Text(`${this.objectiveCount()} 目标`)
            .fontSize(11)
            .fontColor($r('app.color.okr_text_tertiary'))
          Text(`${this.krCount()} KR`)
            .fontSize(11)
            .fontColor($r('app.color.okr_text_tertiary'))
          Text(`${this.ideaCount()} 任务`)
            .fontSize(11)
            .fontColor($r('app.color.okr_text_tertiary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.onOpen(this.projectId);
    })
  }
}
