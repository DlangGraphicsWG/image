module test.main;

import wg.image;
import wg.image.transform;
import wg.color;

int main(string[] args)
{
	// TODO: do something...

    RGB8[4] tinyImage = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
    Image!RGB8 thing = tinyImage.asImage(2, 2);

    thing = thing.crop(1, 2, 1, 2);

	return 0;
}
