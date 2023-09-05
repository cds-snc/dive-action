# Dive action

The purpose of this action is to run `wagoodman/dive` on a Docker image and posts the results as a comment on a PR in GitHub. It can also be used in other actions but will echo the JSON output to the CI/CD console instead. Using `dive` you can see which layers in your Docker image are taking up the most space and which ones are inefficient.

## Configuration

The action is configured using environment variables. The following variables are required:

| Variable | Description |
|--|--|
| `GITHUB_TOKEN` | The GitHub token to use to post the comment. |
| `IMAGE_NAME` | The name of the Docker image to run `dive` on. |

## Example usage

```yaml

- name: Dive into docker image
  uses: cds-snc/dive-action@main
  env: 
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    IMAGE_NAME: "alpine:latest"
```

Just be sure to replace the `IMAGE_NAME` with the name of the image you want to run `dive` on. Most likely something you will have built in a previous step.

## Example output

### Dive image results for `alpine:latest`

| | |
| --- | --- |
| Image | `alpine:latest` |
| Total Size | `7.00MiB` |
| Inefficient Bytes | `0.00B` |
| Efficiency Percentage | `100.00%` |
| Total Layers | `1` |

<details>
<summary>Show full output</summary>

```json
{
  "layer": [
    {
      "index": 0,
      "id": "b1a086cc7b4e637792beecd0316d55b301c5ac60d5988b0df9897b329616ac37",
      "digestId": "sha256:4693057ce2364720d39e57e85a5b8e0bd9ac3573716237736d6470ec5b7b7230",
      "sizeBytes": 7330497,
      "command": "#(nop) ADD file:32ff5e7a78b890996ee4681cc0a26185d3e9acdb4eb1e2aaccb2411f922fed6b in / "
    }
  ],
  "image": {
    "sizeBytes": 7330497,
    "inefficientBytes": 0,
    "efficiencyScore": 1,
    "fileReference": []
  }
}
```