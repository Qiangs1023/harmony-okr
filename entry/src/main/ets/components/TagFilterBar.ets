import { okrTagColor } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrSelectChip } from './OkrCommon';

@ComponentV2
export struct TagFilterBar {
  private names(): string[] {
    return OKR_STORE.tagNames();
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        OkrSelectChip({
          chipText: '全部',
          active: OKR_STORE.activeTag.length === 0,
          chipColor: '#4E7BFF',
          onPick: (): void => {
            OKR_STORE.activeTag = '';
          }
        })
        ForEach(this.names(), (tagName: string) => {
          OkrSelectChip({
            chipText: tagName,
            active: OKR_STORE.activeTag === tagName,
            chipColor: okrTagColor(OKR_STORE.tagColorIndex(tagName)),
            onPick: (): void => {
              OKR_STORE.setActiveTag(tagName);
            }
          })
        }, (tagName: string): string => tagName)
        OkrSelectChip({
          chipText: OKR_STORE.showDone ? '隐藏已完成' : '显示已完成',
          active: !OKR_STORE.showDone,
          chipColor: '#868E96',
          onPick: (): void => {
            OKR_STORE.showDone = !OKR_STORE.showDone;
          }
        })
      }
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(30)
    .edgeEffect(EdgeEffect.None)
  }
}
