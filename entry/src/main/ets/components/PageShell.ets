/** 页面内容最大宽度：平板与折叠屏展开态下居中收窄，避免行长过长 */
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
