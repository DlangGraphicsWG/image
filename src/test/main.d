module test.main;

import wg.image;
import wg.image.transform;

int main(string[] args)
{
	// TODO: do something...

    int[4] tinyImage = [1, 2, 3, 4];
    Image!int thing = fromArray(tinyImage, 2, 2);

    thing = thing.crop(1, 2, 1, 2);

	return 0;
}
