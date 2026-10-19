export const OKR_CONTENT_MAX_WIDTH: number = 720;

@ComponentV2
export struct PageShell {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: OKR_CONTENT_MAX_WIDTH })
    .alignSelf(ItemAlign.Center)
  }
}

/** 详情类页面的卡片容器：圆角白底 + 内边距，承载一组相关字段 */
@ComponentV2
export struct SectionCard {
  @Param cardTitle: string = '';
  @Param cardHint: string = '';
  @Param headerAction: string = '';
  @Event onHeaderAction: () => void = (): void => {
  };
  @BuilderParam content: () => void;

  build() {
    Column({ space: 10 }) {
      if (this.cardTitle.length > 0) {
        Row() {
          Text(this.cardTitle)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.okr_text_secondary'))
          Blank()
          if (this.cardHint.length > 0) {
            Text(this.cardHint)
              .fontSize(11)
              .fontColor($r('app.color.okr_text_tertiary'))
          }
          if (this.headerAction.length > 0) {
            Text(this.headerAction)
              .fontSize(12)
              .fontColor($r('app.color.okr_primary'))
              .margin({ left: 10 })
              .onClick((): void => {
                this.onHeaderAction();
              })
          }
        }
        .width('100%')
      }
      this.content()
    }
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
  }
}
